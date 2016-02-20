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
	cd cosimulation && ./runtest.py
	cd compiler && USE_VERILATOR=1 ./runtest.py
	cd libc && ./runtest.py
	cd misc/atomic/ && ./runtest.py
	cd misc/cache_control/ && ./runtest.py
	cd misc/sdmmc/ && ./runtest.py
	cd misc/fs/ && ./runtest.py
	cd misc/ps2/ && ./runtest.py
	cd misc/uart && ./runtest.py
	cd misc/mmu && ./runtest.py
	cd misc/trap && ./runtest.py
	cd misc/perf_counters && ./runtest.py
	cd misc/shared_memory && ./runtest.py
	cd render && make test
