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


# This needs to be in a subdirectory because you can't have two compilers
# in the same CMakeLists.txt. This builds for the host, the parent directory
# builds for the processor.

project(gen_float_tests)
include(cline_tool)

add_command_line_tool(gen_float_tests
    gen_float_tests.c)

