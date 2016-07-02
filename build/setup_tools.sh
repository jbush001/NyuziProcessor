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

# Configure if necessary
# XXX if the project has been updated, this should probably do a configure again.
if [ ! -f Makefile ]; then
	if [ ! -f configure ]; then
		autoconf
	fi

	./configure
fi

make
sudo make install
)

#
# Build the compiler toolchain
#

if [ ! -d tools/NyuziToolchain/build ]; then
	# Create makefiles. This only needs to be run once. Once the makefiles are
	# created, cmake will reconfigure on its own if necessary when make is
	# invoked.
	mkdir tools/NyuziToolchain/build
	cd tools/NyuziToolchain/build
	cmake -DCMAKE_BUILD_TYPE=Release ..
else
	# The install target leaves some files with root permissions in the
	# build directory. If we are rebuilding, this will cause an error.
	# Change ownership here to fix that.
	cd tools/NyuziToolchain/build
	chown -R `whoami` .
fi

make
sudo make install
