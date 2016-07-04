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

test:
	cd core/atomic/ && ./runtest.py
	cd core/cache_control/ && ./runtest.py
	cd core/mmu && ./runtest.py
	cd core/trap && ./runtest.py
	cd core/perf_counters && ./runtest.py
	cd core/shared_memory && ./runtest.py
	cd device/sdmmc/ && ./runtest.py
	cd device/ps2/ && ./runtest.py
	cd device/uart && ./runtest.py
	cd libc && ./runtest.py
	cd compiler && USE_VERILATOR=1 ./runtest.py
	cd cosimulation && ./runtest.py
	cd render && make test
