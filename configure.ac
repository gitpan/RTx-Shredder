# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT([RTx::Shredder],[0.01],[cubic@wildgate.miee.ru])

AC_CONFIG_SRCDIR([lib/RTx/Shredder.pm])

# Checks for programs.
#AC_PROG_INSTALL

AC_ARG_WITH(rt-lib,
            AC_HELP_STRING([--with-rt-lib=/path/to/rt/lib],
                           [path to your rt lib dir]),
            RT_LIB_PATH=$withval,
            RT_LIB_PATH=/opt/rt3/lib)
AC_SUBST(RT_LIB_PATH)

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([
		 sbin/rtx-shredder],
		[chmod ug=rx,o= sbin/rtx-shredder]
	       )
AC_OUTPUT
