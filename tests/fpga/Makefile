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

# We can't run these automated, but make sure they build
all:
	cd blinky && make
	cd sdmmc_dump && make
	cd sdmmc_native && make
	cd uart_chargen && make

clean:
	cd blinky && make clean
	cd sdmmc_dump && make clean
	cd sdmmc_native && make clean
	cd uart_chargen && make clean
