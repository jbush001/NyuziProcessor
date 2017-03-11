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

function fail {
     echo $1
     exit 1
}

git submodule init || fail "Error initializing submodules"
git submodule update || fail "Error updating submodules"

#
# Build Verilator
#
(
cd tools/verilator

# Configure if necessary
# XXX if the project has been updated, this should probably do a configure again.
if [ ! -f Makefile ]; then
	if [ ! -f configure ]; then
		autoconf || fail "Error creating configuration script for Verilator"
	fi

	./configure || fail "Error configurating Verilator"
fi

make || fail "Error building verilator"
sudo make install || fail "Error installing verilator"
)

#
# Build the compiler toolchain
#
mkdir -p tools/NyuziToolchain/build || fail "Error creating toolchain build directory"

if [ ! -d tools/NyuziToolchain/Makefile ]; then
	# Create makefiles. This only needs to be run once. Once the makefiles are
	# created, cmake will reconfigure on its own if necessary when make is
	# invoked.
	cd tools/NyuziToolchain/build
	cmake -DCMAKE_BUILD_TYPE=Release .. || fail "Error configuring toolchain"
else
	cd tools/NyuziToolchain/build
fi

make || fail "Error building toolchain"
sudo make install || fail "Error installing toolchain"
