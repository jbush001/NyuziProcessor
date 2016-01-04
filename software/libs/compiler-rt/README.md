This library contains low level runtime routines. The compiler generates calls to
these functions for complex operations. It is similar in function to libgcc.a
(https://gcc.gnu.org/onlinedocs/gccint/Libgcc.html) or LLVM's compiler-rt
(http://compiler-rt.llvm.org/).

This should eventually be in the compiler project, but there are some build
system issues with that.
