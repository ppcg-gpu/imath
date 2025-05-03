cmake_minimum_required(VERSION 3.12)
project(IMath VERSION 1.33 LANGUAGES C)

# Options
option(IMATH_BUILD_EXAMPLES "Build example programs" ON)
option(IMATH_USE_32BIT_WORDS "Use 32-bit words instead of 64-bit" OFF)
option(IMATH_ENABLE_TESTING "Enable testing" ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Global compiler flags
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
  add_compile_options(-pedantic -Wall -Werror -Wextra -Wno-unused-parameter)
  set(CMAKE_C_STANDARD 99)
  set(CMAKE_C_STANDARD_REQUIRED ON)
endif()

# Configure options
if(IMATH_USE_32BIT_WORDS)
  add_compile_definitions(USE_32BIT_WORDS)
endif()

# Setup for debug build
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  add_compile_definitions(DEBUG=1)
endif()

# Core libraries
add_library(imath STATIC imath.c)
add_library(imrat STATIC imrat.c)
add_library(iprime STATIC iprime.c)
add_library(gmp_compat STATIC gmp_compat.c)
target_link_libraries(imrat PUBLIC imath)
target_link_libraries(iprime PUBLIC imath)
target_link_libraries(gmp_compat PUBLIC imath)

# Shared library
add_library(libimath SHARED imath.c imrat.c iprime.c gmp_compat.c)
set_target_properties(libimath PROPERTIES 
    OUTPUT_NAME imath
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)

# Test executables
add_executable(imtest imtest.c imdrover.c)
target_link_libraries(imtest PRIVATE imath imrat iprime)

add_executable(imtimer imtimer.c)
target_link_libraries(imtimer PRIVATE imath)

add_executable(bug-swap tests/bug-swap.c)
target_link_libraries(bug-swap PRIVATE imath)

add_executable(bug-qread tests/bug-qread.c)
target_link_libraries(bug-qread PRIVATE imath imrat)

# The pi example is always built, because it is used in CTest
add_executable(pi examples/pi.c)
target_link_libraries(pi PRIVATE imath)

# Add rsamath support
add_library(rsamath STATIC rsamath.c)
target_link_libraries(rsamath PUBLIC imath)

add_executable(rtest tests/rtest.c)
target_link_libraries(rtest PRIVATE imath rsamath)

# Enable testing
if(IMATH_ENABLE_TESTING)
    include(CTest)
   
    # Create tests directory in build dir
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/tests)

    # Copy GMP compatibility test scripts to tests/gmp-compat-test directory
    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/tests/gmp-compat)
    
    file(GLOB GMP_COMPAT_PY_SCRIPTS 
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/gmp-compat-test/genctest.py"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/gmp-compat-test/genpytest.py"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/gmp-compat-test/gendata.py"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/gmp-compat-test/gmpapi.py"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/gmp-compat-test/runtest.py"
    )
    
    foreach(SCRIPT ${GMP_COMPAT_PY_SCRIPTS})
        get_filename_component(SCRIPT_NAME ${SCRIPT} NAME)
	configure_file(${SCRIPT} ${CMAKE_CURRENT_BINARY_DIR}/tests/gmp-compat-test/${SCRIPT_NAME} COPYONLY)
    endforeach()
    
    # Find Python interpreter - required for tests
    find_package(Python REQUIRED COMPONENTS Interpreter)
    
    # Copy test data files to the build directory
    file(GLOB TEST_TC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/tests/*.tc")
    file(GLOB TEST_PI_FILES "${CMAKE_CURRENT_SOURCE_DIR}/tests/pi*.txt")
    
    # Copy test files
    foreach(TEST_FILE ${TEST_TC_FILES} ${TEST_PI_FILES})
        get_filename_component(FILE_NAME ${TEST_FILE} NAME)
        configure_file(${TEST_FILE} ${CMAKE_CURRENT_BINARY_DIR}/tests/${FILE_NAME} COPYONLY)
    endforeach()
    
    # Create the Python test scripts
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_pi_test.py.in
        ${CMAKE_CURRENT_BINARY_DIR}/tests/run_pi_test.py
        @ONLY
    )
    
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_unit_test.py.in
        ${CMAKE_CURRENT_BINARY_DIR}/tests/run_unit_test.py
        @ONLY
    )
    
    # Add individual tests for each .tc file
    foreach(TEST_FILE ${TEST_TC_FILES})
        get_filename_component(TEST_NAME ${TEST_FILE} NAME_WE)
        add_test(
            NAME unit_test_${TEST_NAME}
            COMMAND ${Python_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/tests/run_unit_test.py
                    $<TARGET_FILE:imtest>
                    ${CMAKE_CURRENT_BINARY_DIR}/tests/${TEST_NAME}.tc
        )
    endforeach()
    
    # Add pi computation tests - implemented using Python
    foreach(PI_TEST_CONFIG "1024;10;pi1024.txt" "1698;16;pi1698-16.txt" "1500;10;pi1500-10.txt" "4096;10;pi4096-10.txt")
        list(GET PI_TEST_CONFIG 0 DIGITS)
        list(GET PI_TEST_CONFIG 1 RADIX)
        list(GET PI_TEST_CONFIG 2 REFERENCE_FILE)
        
        add_test(
            NAME pi_test_${DIGITS}_${RADIX}
            COMMAND ${Python_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/tests/run_pi_test.py
                    $<TARGET_FILE:pi>
                    ${DIGITS}
                    ${RADIX}
                    ${CMAKE_CURRENT_BINARY_DIR}/tests/${REFERENCE_FILE}
        )
    endforeach()
    
    # Add bug regression tests
    add_test(NAME bug_swap_test COMMAND bug-swap)
    add_test(NAME bug_qread_test COMMAND bug-qread)

    # GMP compatibility tests
    # Include the GmpCompatTest module
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/GmpCompatTest.cmake)
    
    # Create combined check target that includes all tests
    add_custom_target(check 
        COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
        COMMENT "Running all tests"
        DEPENDS imtest pi bug-swap bug-qread gmp_test_lib imath_test_lib
    )
endif()

# Build examples
if(IMATH_BUILD_EXAMPLES)
    # List of example programs
    set(EXAMPLES
        basecvt
        findprime
        imcalc
        input
        randprime
        rounding
        rsakey
    )
    
    # Build each example
    foreach(EXAMPLE ${EXAMPLES})
        add_executable(example_${EXAMPLE} examples/${EXAMPLE}.c)
        set_target_properties(example_${EXAMPLE} PROPERTIES OUTPUT_NAME ${EXAMPLE})
        target_link_libraries(example_${EXAMPLE} PRIVATE imath imrat iprime)
    endforeach()
endif()

# Format code target
if(CMAKE_C_COMPILER_ID MATCHES "Clang")
    find_program(CLANG_FORMAT clang-format)
    if(CLANG_FORMAT)
        add_custom_target(format-c
            COMMAND find . -type f -name '*.h' -o -name '*.c' -print0 | 
                    xargs -0 ${CLANG_FORMAT} --style=Google -i
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMENT "Formatting C source files and headers with clang-format..."
        )
    endif()
endif()

find_program(YAPF yapf)
if(YAPF)
    add_custom_target(format-py
        COMMAND find . -type f -name '*.py' -print0 | 
                xargs -0 ${YAPF} --style=pep8 -i
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Formatting Python source files with yapf..."
    )
endif()

if(TARGET format-c AND TARGET format-py)
    add_custom_target(format DEPENDS format-c format-py)
endif()

# Docker test target
add_custom_target(docker-image
    COMMAND docker build -t imath/test-runner -f tests/linux/Dockerfile ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building Docker test image"
)

add_custom_target(docker-test
    COMMAND docker run --rm -it imath/test-runner:latest
    DEPENDS docker-image
    COMMENT "Running tests in Docker container"
)

# Documentation generation
add_custom_target(doc.md
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tools/mkdoc.py 
            ${CMAKE_CURRENT_SOURCE_DIR}/doc.md.in 
	    ${CMAKE_CURRENT_BINARY_DIR}/doc.md
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/doc.md.in
            ${CMAKE_CURRENT_SOURCE_DIR}/imath.h
            ${CMAKE_CURRENT_SOURCE_DIR}/imrat.h
            ${CMAKE_CURRENT_SOURCE_DIR}/tools/mkdoc.py
    COMMENT "Generating documentation"
)

# Installation
include(GNUInstallDirs)
install(TARGETS imath imrat iprime gmp_compat libimath
    EXPORT IMathTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES imath.h imrat.h iprime.h gmp_compat.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Generate and install package configuration
include(CMakePackageConfigHelpers)
configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/IMathConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/IMathConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/IMath
    PATH_VARS CMAKE_INSTALL_INCLUDEDIR CMAKE_INSTALL_LIBDIR
)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/IMathConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/IMathConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/IMathConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/IMath
)
install(EXPORT IMathTargets
    FILE IMathTargets.cmake
    NAMESPACE IMath::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/IMath
)

# Define clean and distclean targets similar to the original Makefile
add_custom_target(distclean
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}
    COMMENT "Removing all build artifacts"
)
