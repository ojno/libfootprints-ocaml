#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/bigarray.h>
#include <caml/fail.h>

#include <libfootprints/footprints.h>
#include <libfootprints/perform_syscall.h>

static inline value caml_alloc_some(value v) {
	value option = caml_alloc_small(1, 0); // Some
	Field(option, 0) = v;
	return option;
}

static inline value caml_list_head(value list) {
	return Field(list, 0);
}

static inline value caml_list_tail(value list) {
	return Field(list, 1);
}

void syscall_env_finalize(value env_val) {
	CAMLparam1(env_val);
	CAMLreturn0;
}

void syscall_state_finalize(value state_val) {
	CAMLparam1(state_val);
	CAMLreturn0;
}

CAMLprim value caml_syscall_state_finished(value state_val) {
	CAMLparam1(state_val);
	struct syscall_state *state = *((struct syscall_state**) Data_custom_val(state_val));
	CAMLreturn(Val_bool(state->finished));
}

CAMLprim value caml_syscall_state_retval(value state_val) {
	CAMLparam1(state_val);
	CAMLlocal1(result);
	struct syscall_state *state = *((struct syscall_state**) Data_custom_val(state_val));
	result = caml_copy_nativeint((intnat) state->retval);
	CAMLreturn(result);
}

CAMLprim value caml_syscall_state_needed_extents(value state_val) {
	CAMLparam1(state_val);
	CAMLlocal3(tail, cons, caml_node);
	tail = Val_emptylist;
	struct syscall_state *state = *((struct syscall_state**) Data_custom_val(state_val));
	struct extent_node *current = state->need_memory_extents;
	while (current != NULL) {
		caml_node = caml_alloc_small(3, 0);
        /* Marshal from our extent_node linked list of
		   extent {size_t base, size_t length}
		   to an OCaml list of {nativeint, nativeint, None} */
		caml_node = caml_alloc_small(3, 0);
		Field(caml_node, 0) = caml_copy_nativeint((intnat)current->extent.base);
		intnat length = (intnat) current->extent.length;
		Field(caml_node, 1) = caml_copy_nativeint(length);
		Field(caml_node, 2) = Val_int(0); // None
		cons = caml_alloc_small(2, 0);
		Field(cons, 0) = caml_node;
		Field(cons, 1) = tail;
		tail = cons;
		current = current->next;
	}
	CAMLreturn(tail);
}

CAMLprim value caml_syscall_state_write_extents(value state_val) {
	CAMLparam1(state_val);
	CAMLlocal5(tail, cons, caml_node, caml_node_data, option);
	tail = Val_emptylist;
	struct syscall_state *state = *((struct syscall_state**) Data_custom_val(state_val));
	if (!state->finished) {
		caml_failwith("caml_syscall_state_write_extents called with unfinished syscall");
	}
	struct data_extent_node *current = state->write_extents;
	while (current != NULL) {
		/* Marshal from our data_extent_node linked list of
		   data_extent {size_t base, size_t length, void *data}
		   to an OCaml list of {nativeint, nativeint, Some(bigarray)} */
		caml_node = caml_alloc_small(3, 0);
		Field(caml_node, 0) = caml_copy_nativeint((intnat)current->extent.base);
		intnat length = (intnat) current->extent.length;
		Field(caml_node, 1) = caml_copy_nativeint(length);
		caml_node_data = caml_ba_alloc(CAML_BA_UINT8 | CAML_BA_C_LAYOUT, 1, NULL, &length);
		memcpy(Caml_ba_data_val(caml_node_data), current->extent.data, length);
		option = caml_alloc_small(1, 0); // Some
		Field(option, 0) = caml_node_data;
		Field(caml_node, 2) = option;
		cons = caml_alloc_small(2, 0);
		Field(cons, 0) = caml_node;
		Field(cons, 1) = tail;
		tail = cons;
		current = current->next;
	}
	CAMLreturn(tail);
}

CAMLprim value caml_load_syscall_footprints_from_file(value filename_val) {
	CAMLparam1(filename_val);
	CAMLlocal2(result, option);
	char *filename = String_val(filename_val);
	struct syscall_env env;
	_Bool success = load_syscall_footprints_from_file(filename, &env);
	if (success) {
		result = caml_alloc_final(sizeof(struct syscall_env), &syscall_env_finalize, 0, 1);
		*((struct syscall_env*)Data_custom_val(result)) = env;
		option = caml_alloc_some(result);
		CAMLreturn(option);
	} else {
		CAMLreturn(Val_int(0)); // None
	}
}

CAMLprim value caml_start_syscall(value env_val, value num_val, value args_val) {
	CAMLparam3(env_val, num_val, args_val);
	CAMLlocal1(result);
	struct syscall_env *env = ((struct syscall_env*) Data_custom_val(env_val));
	intnat num = Nativeint_val(num_val);
	if (Wosize_val(args_val) > 6) {
		caml_failwith("caml_start_syscall got an args array of length > 6");
	}
	long int args[6] = {0};
	for (int i = 0; i < Wosize_val(args_val); i++) {
		args[i] = Nativeint_val(Field(args_val, i));
	}
	struct syscall_state *state = start_syscall(env, num, args);
	result = caml_alloc_final(sizeof(struct syscall_state*), &syscall_state_finalize, 0, 1);
	*((struct syscall_state**) Data_custom_val(result)) = state;
	CAMLreturn(result);
}

CAMLprim value caml_continue_syscall(value state_val, value extents_val) {
	CAMLparam2(state_val, extents_val);
	CAMLlocal5(current, option, current_head, result, bigarray);
	struct syscall_state *state = *((struct syscall_state**) Data_custom_val(state_val));
	struct data_extent_node *tail = NULL;
	current = extents_val;
	while (current != Val_emptylist) {
		current_head = Field(current, 0);
		intnat base = Nativeint_val(Field(current_head, 0));
		intnat length = Nativeint_val(Field(current_head, 1));
		option = Field(current_head, 2);
		if (option == Val_int(0)) { // None 
			caml_failwith("caml_continue_syscall got an ocaml extent with data = None");
		}
		bigarray = Field(option, 0);
		if (Caml_ba_array_val(bigarray)->dim[0] != length) {
			caml_failwith("caml_continue_syscall got an ocaml extent with bigarraylength != length");
		}
		tail = data_extent_node_new_with(base, length, Caml_ba_data_val(bigarray), tail);
		current = caml_list_tail(current);
	}
	struct syscall_state *new_state = continue_syscall(state, tail);
	result = caml_alloc_final(sizeof(struct syscall_state*), &syscall_state_finalize, 0, 1);
	*((struct syscall_state**) Data_custom_val(result)) = new_state;
	CAMLreturn(result);
}
