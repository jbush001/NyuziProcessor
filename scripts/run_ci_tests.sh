#!/bin/bash
#
# Copyright 2015 Jeff Bush
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

#
# This script is executed when by TravisCI to build everything and run
# automated tests.
#
set -e  # Exit automatically if any of these commands fail

(cd tests/cosimulation
./generate_random.py -m 3)

# Print versions of pre-installed tools
verilator --version
/usr/local/llvm-nyuzi/bin/clang -v

# Build out of tree
mkdir build
cd build
cmake ..
make -j 8
make tests
