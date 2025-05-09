#!/usr/bin/env python3

from __future__ import print_function

import ctypes
import os
from optparse import OptionParser
import sys

import gmpapi
import wrappers
from gmpapi import charp, iint, ilong, mpq_t, mpz_t, size_t, size_tp, ulong, voidp


def print_failure(line, test):
    print("FAIL: {}@{}".format(line, test))


def run_tests(test_file, options):
    passes = 0
    failures = 0
    fail_lines = []
    for (line, test) in enumerate(open(test_file), start=1):
        if test.startswith("#"):
            continue
        if options.skip > 0 and line < options.skip:
            continue
        name, args = test.split("|")
        if options.verbose or (options.progress > 0
                               and line % options.progress == 0):
            print("TEST: {}@{}".format(line, test), end="")
        api = gmpapi.get_api(name)
        wrapper = wrappers.get_wrapper(name)
        input_args = args.split(",")
        if len(api.params) != len(input_args):
            raise RuntimeError("Mismatch in args length: {} != {}".format(
                len(api.params), len(input_args)))

        call_args = []
        for i in range(len(api.params)):
            param = api.params[i]
            if param == mpz_t:
                call_args.append(input_args[i].encode('utf-8'))
            elif param == mpq_t:
                call_args.append(input_args[i].encode('utf-8'))
            elif param == ulong:
                call_args.append(ctypes.c_ulong(int(input_args[i])))
            elif param == ilong:
                call_args.append(ctypes.c_long(int(input_args[i])))
            elif param == voidp or param == size_tp:
                call_args.append(ctypes.c_void_p(None))
            elif param == size_t:
                call_args.append(ctypes.c_size_t(int(input_args[i])))
            elif param == iint:
                call_args.append(ctypes.c_int(int(input_args[i])))
            # pass null for charp
            elif param == charp:
                if input_args[i] == "NULL":
                    call_args.append(ctypes.c_void_p(None))
                else:
                    call_args.append(input_args[i].encode("utf-8"))
            else:
                raise RuntimeError("Unknown param type: {}".format(param))

        res = wrappers.run_test(wrapper, line, name, gmp_test_so,
                                imath_test_so, *call_args)
        if not res:
            failures += 1
            print_failure(line, test)
            fail_lines.append((line, test))
        else:
            passes += 1
    return (passes, failures, fail_lines)


def parse_args():
    parser = OptionParser()
    parser.add_option("-f",
                      "--fork",
                      help="fork() before each operation",
                      action="store_true",
                      default=False)
    parser.add_option("-v",
                      "--verbose",
                      help="print PASS and FAIL tests",
                      action="store_true",
                      default=False)
    parser.add_option("-p",
                      "--progress",
                      help="print progress every N tests ",
                      metavar="N",
                      type="int",
                      default=0)
    parser.add_option("-s",
                      "--skip",
                      help="skip to test N",
                      metavar="N",
                      type="int",
                      default=0)
    return parser.parse_args()


def load_library(lib_path):
    """Platform-agnostic library loading function"""
    if not os.path.exists(lib_path):
        raise RuntimeError(f"Library not found: {lib_path}")
    
    try:
        return ctypes.cdll.LoadLibrary(lib_path)
    except Exception as e:
        raise RuntimeError(f"Failed to load library {lib_path}: {e}")


if __name__ == "__main__":
    (options, tests) = parse_args()
    
    # Get library paths from environment variables - these are set by run_gmp_compat_test.py
    gmp_lib_path = os.environ.get('GMP_TEST_LIB')
    imath_lib_path = os.environ.get('IMATH_TEST_LIB')
    
    if not gmp_lib_path or not imath_lib_path:
        print("ERROR: Library paths not provided in environment variables")
        print("Make sure GMP_TEST_LIB and IMATH_TEST_LIB are set")
        sys.exit(1)
    
    try:
        gmp_test_so = load_library(gmp_lib_path)
        imath_test_so = load_library(imath_lib_path)
    except RuntimeError as e:
        print(f"ERROR: {e}")
        sys.exit(1)

    wrappers.verbose = options.verbose
    wrappers.fork = options.fork

    total_pass = 0
    total_fail = 0
    all_fail_lines = []
    for test_file in tests:
        print("Running tests in {}".format(test_file))
        (passes, failures, fail_lines) = run_tests(test_file, options)
        print("  Tests: {}. Passes: {}. Failures: {}.".format(
            passes + failures, passes, failures))
        total_pass += passes
        total_fail += failures
        all_fail_lines += fail_lines

    print("=" * 70)
    print("Total")
    print("  Tests: {}. Passes: {}. Failures: {}.".format(
        total_pass + total_fail, total_pass, total_fail))
    if len(all_fail_lines) > 0:
        print("Failing Tests:")
        for (line, test) in all_fail_lines:
            print(test.rstrip())
