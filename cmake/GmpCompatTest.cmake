# GMP Compatibility Test Module
#
# This module sets up GMP compatibility tests using CTest
# It replaces the custom Makefile in tests/gmp-compat-test

# Find GMP package (required for compatibility tests)
find_package(GMP REQUIRED)

# Find Python interpreter (required for test generation scripts)
find_package(Python REQUIRED COMPONENTS Interpreter)

# Set up paths
set(GMP_COMPAT_TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/tests/gmp-compat-test)
set(GMP_COMPAT_SCRIPT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cmake/gmp-compat)
set(GMP_COMPAT_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/tests/gmp-compat-test)

# Create output directory
file(MAKE_DIRECTORY ${GMP_COMPAT_BINARY_DIR})

# Copy needed files to build directory
file(GLOB GMP_COMPAT_PY_FILES 
     "${GMP_COMPAT_SCRIPT_DIR}/*.py"
     "${GMP_COMPAT_TEST_DIR}/*.py"
)

file(GLOB GMP_COMPAT_C_FILES 
     "${GMP_COMPAT_TEST_DIR}/*_custom_test.c"
)

foreach(FILE ${GMP_COMPAT_PY_FILES} ${GMP_COMPAT_C_FILES})
    get_filename_component(FILENAME ${FILE} NAME)
    configure_file(${FILE} ${GMP_COMPAT_BINARY_DIR}/${FILENAME} COPYONLY)
endforeach()

# Generate test files
add_custom_command(
    OUTPUT ${GMP_COMPAT_BINARY_DIR}/gmp_test.c
    COMMAND ${Python_EXECUTABLE} ${GMP_COMPAT_BINARY_DIR}/genctest.py gmp > ${GMP_COMPAT_BINARY_DIR}/gmp_test.c
    DEPENDS ${GMP_COMPAT_BINARY_DIR}/genctest.py ${GMP_COMPAT_BINARY_DIR}/gmpapi.py ${GMP_COMPAT_BINARY_DIR}/gmp_custom_test.c
    WORKING_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
    COMMENT "Generating GMP test code"
)

add_custom_command(
    OUTPUT ${GMP_COMPAT_BINARY_DIR}/imath_test.c
    COMMAND ${Python_EXECUTABLE} ${GMP_COMPAT_BINARY_DIR}/genctest.py imath > ${GMP_COMPAT_BINARY_DIR}/imath_test.c
    DEPENDS ${GMP_COMPAT_BINARY_DIR}/genctest.py ${GMP_COMPAT_BINARY_DIR}/gmpapi.py ${GMP_COMPAT_BINARY_DIR}/imath_custom_test.c
    WORKING_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
    COMMENT "Generating IMath test code"
)

add_custom_command(
    OUTPUT ${GMP_COMPAT_BINARY_DIR}/wrappers.py
    COMMAND ${Python_EXECUTABLE} ${GMP_COMPAT_BINARY_DIR}/genpytest.py > ${GMP_COMPAT_BINARY_DIR}/wrappers.py
    DEPENDS ${GMP_COMPAT_BINARY_DIR}/genpytest.py ${GMP_COMPAT_BINARY_DIR}/gmpapi.py
    WORKING_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
    COMMENT "Generating Python wrappers"
)

add_custom_command(
    OUTPUT ${GMP_COMPAT_BINARY_DIR}/random.tests
    COMMAND ${Python_EXECUTABLE} ${GMP_COMPAT_BINARY_DIR}/gendata.py > ${GMP_COMPAT_BINARY_DIR}/random.tests
    DEPENDS ${GMP_COMPAT_BINARY_DIR}/gendata.py ${GMP_COMPAT_BINARY_DIR}/gmpapi.py
    WORKING_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
    COMMENT "Generating test data"
)

# Add targets for the test libraries
add_library(gmp_test_lib SHARED ${GMP_COMPAT_BINARY_DIR}/gmp_test.c)
set_target_properties(gmp_test_lib PROPERTIES
    OUTPUT_NAME gmp_test
    LIBRARY_OUTPUT_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
)
target_link_libraries(gmp_test_lib GMP::gmp)

add_library(imath_test_lib SHARED ${GMP_COMPAT_BINARY_DIR}/imath_test.c)
set_target_properties(imath_test_lib PROPERTIES
    OUTPUT_NAME imath_test
    LIBRARY_OUTPUT_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
)
target_include_directories(imath_test_lib PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries(imath_test_lib imath)

# Create target that depends on all generated files
add_custom_target(gmp_compat_test_files
    DEPENDS 
        ${GMP_COMPAT_BINARY_DIR}/gmp_test.c
        ${GMP_COMPAT_BINARY_DIR}/imath_test.c
        ${GMP_COMPAT_BINARY_DIR}/wrappers.py
        ${GMP_COMPAT_BINARY_DIR}/random.tests
)

# Add dependencies between targets
add_dependencies(gmp_test_lib gmp_compat_test_files)
add_dependencies(imath_test_lib gmp_compat_test_files)

# Create the test runner script in the build directory
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_gmp_compat_test.py.in
    ${GMP_COMPAT_BINARY_DIR}/run_gmp_compat_test.py
    @ONLY
)

# Add the test with CTest
add_test(
    NAME gmp_compat_test
    COMMAND ${Python_EXECUTABLE} ${GMP_COMPAT_BINARY_DIR}/run_gmp_compat_test.py
    WORKING_DIRECTORY ${GMP_COMPAT_BINARY_DIR}
)

# Set environment variables for the test
set_tests_properties(gmp_compat_test PROPERTIES
    ENVIRONMENT "GMP_TEST_LIB=$<TARGET_FILE:gmp_test_lib>;IMATH_TEST_LIB=$<TARGET_FILE:imath_test_lib>"
)

# Create a custom target that runs the test
add_custom_target(run_gmp_compat_test
    COMMAND ${CMAKE_CTEST_COMMAND} -R gmp_compat_test --output-on-failure
    DEPENDS gmp_test_lib imath_test_lib
    COMMENT "Running GMP compatibility tests"
)
