(***** Types *****)

type state
type env

type extent = {
    base : nativeint;
    length : nativeint;
    data : ((char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t) option;
  }

type result =
  | Finished of (* retval : *) nativeint * (* write_footprint : *) extent list
  | MoreDataNeeded of state * (* read_footprint : *) extent list


(***** Utility functions *****)

external _c_start_syscall : env -> nativeint -> nativeint array -> state = "caml_start_syscall"
external _c_continue_syscall : state -> extent list -> state = "caml_continue_syscall"
external _c_syscall_state_write_extents : state -> extent list = "caml_syscall_state_write_extents"
external _c_syscall_state_needed_extents : state -> extent list = "caml_syscall_state_needed_extents"
external _c_syscall_state_finished : state -> bool = "caml_syscall_state_finished"
external _c_syscall_state_retval : state -> nativeint = "caml_syscall_state_retval"

let _check_c_retval state =
  if _c_syscall_state_finished state then
    Finished (_c_syscall_state_retval state, _c_syscall_state_write_extents state)
  else
    MoreDataNeeded (state, _c_syscall_state_needed_extents state)

(***** Public API *****)

external load_footprints_from_file : string -> env option = "caml_load_syscall_footprints_from_file"

let start_syscall env num args =
  let new_state = _c_start_syscall env num args in
  _check_c_retval new_state

let continue_syscall state extents =
  let new_state = _c_continue_syscall state extents in
  _check_c_retval new_state

