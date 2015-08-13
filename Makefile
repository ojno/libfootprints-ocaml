default: test_syscalls.native test_syscalls.byte

-include config.mk

PREFIX ?= $(shell pwd)/..
PREFIX := $(realpath $(PREFIX))

LIBDIR := $(PREFIX)/lib
STDLIB := $(shell ocamlc -where)

OCAMLC ?= ocamlc -verbose
OCAMLOPT ?= ocamlopt -verbose
OCAMLMKLIB ?= ocamlmklib -verbose

A_SUFFIX ?= .a
SO_SUFFIX ?= .so
NATIVE_SUFFIX ?= .native
BYTE_SUFFIX ?= .byte
O_SUFFIX ?= .o

null := #
space := $(null) #
comma := ,

CFLAGS += -std=gnu99 -ggdb3 -fPIC $(shell pkg-config --cflags-only-I libfootprints)

OCAMLFLAGS := -thread -g
OCAMLOPTFLAGS := -thread -g

LDFLAGS += -Xlinker --no-as-needed

FOOTPRINTS_CFLAGS := $(shell pkg-config --cflags libfootprints)
FOOTPRINTS_LIBS := $(shell pkg-config --libs libfootprints)

ifeq ($(FOOTPRINTS_CFLAGS),)
$(error FOOTPRINTS_CFLAGS)
endif

ifeq ($(FOOTPRINTS_LIBS),)
$(error FOOTPRINTS_LIBS)
endif

OCAML_LDFLAGS := $(foreach flag,$(LDFLAGS),-cclib $(subst $(space),$(comma),$(flag)))
OCAML_FOOTPRINTS_LIBS := $(foreach flag,$(FOOTPRINTS_LIBS),-cclib $(subst $(space),$(comma),$(flag)))

syscalls.cmx: syscalls.cmi
syscalls.cmxa syscalls$(A_SUFFIX): syscalls.cmx
	$(OCAMLMKLIB) -o syscalls $+ $(OCAML_LDFLAGS) $(FOOTPRINTS_LIBS)

libsyscalls$(A_SUFFIX) dllsyscalls$(SO_SUFFIX): libfootprints_ocaml_stubs.o
	$(OCAMLMKLIB) -o syscalls $+ $(OCAML_LDFLAGS) $(FOOTPRINTS_LIBS)

syscalls.cmo: syscalls.cmi
syscalls.cma: syscalls.cmo
	$(OCAMLMKLIB) -o syscalls $+ $(OCAML_LDFLAGS) $(FOOTPRINTS_LIBS)

test_syscalls$(NATIVE_SUFFIX): syscalls.cmxa test_syscalls.cmx libsyscalls$(A_SUFFIX)
	$(OCAMLOPT) $(OCAMLOPTFLAGS) $(OCAMLINC) bigarray.cmxa -ccopt -L. $+ -o $@ $(OCAML_LDFLAGS)

test_syscalls$(BYTE_SUFFIX): syscalls.cma test_syscalls.cmo libsyscalls$(A_SUFFIX)
	$(OCAMLC) $(OCAMLFLAGS) $(OCAMLINC) bigarray.cma -ccopt -L. $+ -o $@ $(OCAML_LDFLAGS)

%.cmi: %.mli
	$(OCAMLC) $(OCAMLFLAGS) $(OCAMLINC) -c $<

%.cmo: %.ml %.cmi
	$(OCAMLC) $(OCAMLFLAGS) $(OCAMLINC) -c $<

%.cmx: %.ml %.cmi
	$(OCAMLOPT) $(OCAMLOPTFLAGS) $(OCAMLINC) -c $<

%.cmo: %.ml
	$(OCAMLC) $(OCAMLFLAGS) $(OCAMLINC) -c $<

%.cmx: %.ml
	$(OCAMLOPT) $(OCAMLOPTFLAGS) $(OCAMLINC) -c $<

%.$(O_SUFFIX): %.c
	$(OCAMLC) -ccopt "$(CFLAGS)" -ccopt "$(FOOTPRINTS_CFLAGS)" -c $<

.PHONY: clean
clean:
	/bin/rm -rf *$(O_SUFFIX) *$(A_SUFFIX) *$(SO_SUFFIX) *.cmi *.cmo *.cmx *.cmxa *.cmxs *.cma test_syscalls.byte test_syscalls.native
