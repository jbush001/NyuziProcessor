#
# Copyright 2018 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

project(float_tests)
add_subdirectory(gen_float_tests)
include(nyuzi)

add_nyuzi_executable(float_test_runner
    SOURCES
    run_tests.c
    ${CMAKE_CURRENT_BINARY_DIR}/test_cases.s)
add_dependencies(float_test_runner float_test_cases_s)
target_link_libraries(float_test_runner
    c
    os-bare)

# Generate the test cases assembly file, which will be compiled in. This is
# assembly rather than a C array because it builds *much* faster, especially
# with hundreds of thousands of test vectors.
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/test_cases.s
    COMMAND $<TARGET_FILE:gen_float_tests> > ${CMAKE_CURRENT_BINARY_DIR}/test_cases.s
    COMMENT "Generating floating point test cases")
add_custom_target(float_test_cases_s
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/test_cases.s gen_float_tests)
