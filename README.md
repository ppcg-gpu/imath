IMath
=====

Arbitrary precision integer and rational arithmetic library.

[![Unit tests](https://github.com/creachadair/imath/workflows/Unit%20tests/badge.svg)](https://github.com/creachadair/imath/actions/workflows/unit-tests.yml)

IMath is an open-source ISO C arbitrary precision integer and rational
arithmetic library.

IMath is copyright &copy; 2002-2009 Michael J. Fromberger.

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.


About IMath
-----------

IMath is a library written in portable ISO C that allows you to perform
arithmetic on integers and rational numbers of arbitrary precision.  While many
programming languages, including Java, Perl, and Python provide arbitrary
precision numbers as a standard library or language feature, C does not.

IMath was designed to be small, self-contained, easy to understand and use, and
as portable as possible across various platforms.  The API is simple, and the
code should be comparatively easy to modify or extend.  Simplicity and
portability are useful goals for some applications&#8212;however, IMath does
not attempt to break performance records.  If you need the fastest possible
implementation, you might consider some other libraries, such as GNU MP (GMP),
MIRACL, or the bignum library from OpenSSL.

Building IMath
-------------

IMath uses CMake as its build system. To build the library, run:

```bash
mkdir build
cd build
cmake ..
cmake --build .
```

To run the tests:

```bash
cd build
ctest --output-on-failure
```

To build with specific options:

```bash
cmake -DIMATH_BUILD_EXAMPLES=ON -DIMATH_ENABLE_TESTING=ON ..
```

Available CMake options:
- `IMATH_BUILD_EXAMPLES` (default: ON) - Build example programs
- `IMATH_USE_32BIT_WORDS` (default: OFF) - Use 32-bit words instead of 64-bit
- `IMATH_ENABLE_TESTING` (default: ON) - Enable testing

To install the library:

```bash
cmake --build . --target install
```

Programming with IMath
----------------------

Detailed descriptions of the IMath API can be found in [doc.md](doc.md).
However, the following is a brief synopsis of how to get started with some
simple tasks.

To do basic integer arithmetic, you must declare variables of type `mpz_t` in
your program, and call the functions defined in `imath.h` to operate on them.
Here is a simple example that reads one base-10 integer from the command line,
multiplies it by another (fixed) value, and prints the result to the standard
output in base-10 notation:

```c
#include <stdio.h>
#include <stdlib.h>
#include "imath.h"

int main(int argc, char *argv[])
{
  mpz_t  a, b;
  char  *buf;
  int    len;

  if(argc < 2) {
    fprintf(stderr, "Usage: testprogram <integer>\n");
    return 1;
  }

  /* Initialize a new zero-valued mpz_t structure */
  mp_int_init(&a);

  /* Initialize a new mpz_t with a small integer value */
  mp_int_init_value(&b, 25101);

  /* Read a string value in the specified radix */
  mp_int_read_string(&a, 10, argv[1]);

  /* Multiply the two together... */
  mp_int_mul(&a, &b, &a);

  /* Print out the result */
  len = mp_int_string_len(&a, 10);
  buf = calloc(len, sizeof(*buf));
  mp_int_to_string(&a, 10, buf, len);
  printf("result = %s\n", buf);
  free(buf);

  /* Release memory occupied by mpz_t structures when finished */
  mp_int_clear(&b);
  mp_int_clear(&a);

  return 0;
}
```

This simple example program does not do any error checking, but all the IMath
API functions return an `mp_result` value which can be used to detect various
problems like range errors, running out of memory, and undefined results.

The IMath API also supports operations on arbitrary precision rational numbers.
The functions for creating and manipulating rational values (type `mpq_t`) are
defined in `imrat.h`, so that you need only include them in your project if you
wish to.

Using IMath in Your Project
---------------------------

If you use CMake for your project, you can include IMath as a dependency:

```cmake
find_package(IMath REQUIRED)
target_link_libraries(your_target PRIVATE IMath::imath)
```

If installing IMath to a non-standard location, you can specify the path:

```bash
cmake -DCMAKE_PREFIX_PATH=/path/to/imath/install ..
```
