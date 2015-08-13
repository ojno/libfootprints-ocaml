AC_CONFIG_MACRO_DIR([m4])
AC_PREREQ([2.69])
AC_INIT([libfootprints-ocaml], [0.1], [jf451@cl.cam.ac.uk])
AC_CONFIG_SRCDIR([syscalls.ml])

CFLAGS="-I$prefix/include $CFLAGS"
CXXFLAGS="-I$prefix/include $CXXFLAGS"
CPPFLAGS="-I$prefix/include $CPPFLAGS"
LDFLAGS="-L$prefix/lib $LDFLAGS"
PKG_CONFIG_PATH="$prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
export CFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH

AC_LANG([C])
AC_PROG_CC

AC_CHECK_HEADER_STDBOOL
AC_C_INLINE
AC_TYPE_SIZE_T
AC_PROG_LN_S
AC_PROG_INSTALL

PKG_PROG_PKG_CONFIG
PKG_CHECK_MODULES([LIBFOOTPRINTS], [libfootprints])

AC_ARG_VAR([OCAMLC], [path to ocamlc])
AC_PATH_PROG([OCAMLC], [ocamlc], [])
if (test "x$OCAMLC" = "x") 2>/dev/null; then
   AC_MSG_FAILURE([ocamlc is required])
fi

AC_ARG_VAR([OCAMLOPT], [path to ocamlopt])
AC_PATH_PROG([OCAMLOPT], [ocamlopt], [])
if (test "x$OCAMLOPT" = "x") 2>/dev/null; then
   AC_MSG_FAILURE([ocamlopt is required])
fi

AC_ARG_VAR([OCAMLMKLIB], [path to ocamlmklib])
AC_PATH_PROG([OCAMLMKLIB], [ocamlmklib], [])
if (test "x$OCAMLMKLIB" = "x") 2>/dev/null; then
   AC_MSG_FAILURE([ocamlmklib is required])
fi

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
