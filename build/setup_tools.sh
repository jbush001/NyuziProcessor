#!/bin/bash
#
# Copyright 2016 Jeff Bush
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

git submodule init
git submodule update

#
# Build Verilator
#
(
cd tools/verilator
autoconf
./configure
make
sudo make install
)

#
# Build the compiler toolchain
#
mkdir tools/NyuziToolchain/build
cd tools/NyuziToolchain/build
cmake -DCMAKE_BUILD_TYPE=Release ..
make
sudo make install

