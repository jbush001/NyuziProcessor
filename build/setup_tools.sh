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

#
# Download and build the latest version of Verilator
#
(
git clone http://git.veripool.org/git/verilator tools/verilator
cd tools/verilator
git checkout -b verilator_3_880
autoconf
./configure
make
sudo make install
)

#
# Download and build the compiler
#
git clone https://github.com/jbush001/NyuziToolchain.git tools/NyuziToolchain
mkdir tools/NyuziToolchain/build
cd tools/NyuziToolchain/build
cmake ..
make
sudo make install

