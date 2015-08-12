-include config.mk

PREFIX ?= $(shell pwd)/..
PREFIX := $(realpath $(PREFIX))

LIBDIR := $(PREFIX)/lib
STDLIB := $(shell ocamlfind query stdlib)

default: test_syscalls.native

.PHONY: make-ctypes
make-ctypes:
	$(MAKE) -C ocaml-ctypes

.PHONY: test_syscalls.native
test_syscalls.native: make-ctypes
	ocamlbuild test_syscalls.native \
		-cflags -thread \
		-I src \
		-I ocaml-bytes \
		-I ocaml-ctypes/src/ctypes-top \
		-I ocaml-ctypes/src/ctypes-foreign-unthreaded \
		-I ocaml-ctypes/src/cstubs \
		-I ocaml-ctypes/src/ctypes-foreign-threaded \
		-I ocaml-ctypes/src/ctypes-foreign-base \
		-I ocaml-ctypes/src/libffi-abigen \
		-I ocaml-ctypes/src/ctypes \
		-lflags -linkall -lflags -cclib,-Xlinker -lflags -cclib,--no-as-needed \
		-lflags -cclib,-Xlinker -lflags -cclib,-rpath -lflags -cclib,-Xlinker -lflags -cclib,$(LIBDIR) \
		-lflags -cclib,-Xlinker -lflags -cclib,-rpath -lflags -cclib,-Xlinker -lflags -cclib,$(STDLIB) \
		-tag thread -lib bigarray -lib str -lib unix \
		-lflags -cclib,-L$(STDLIB) \
		-lflags -cclib,-L$(LIBDIR) \
		-lflags -cclib,-L$(shell pwd)/ocaml-ctypes/_build \
		-lflags -cclib,-lctypes_stubs -lflags -cclib,-lctypes-foreign-base_stubs -lflags -cclib,-lffi \
		-lflags -cclib,-lfootprints -lflags -cclib,-lfootprints_syscalls 
