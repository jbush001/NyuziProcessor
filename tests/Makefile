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

PYTHON=python3

test:
	cd unit && $(PYTHON) ./runtest.py
	cd remote-gdb && $(PYTHON) ./runtest.py
	cd jtag-debug && $(PYTHON) ./runtest.py
	cd core/isa/ && $(PYTHON) ./runtest.py
	cd core/cache_control/ && $(PYTHON) ./runtest.py
	cd core/mmu && $(PYTHON) ./runtest.py
	cd core/trap && $(PYTHON) ./runtest.py
	cd core/perf_counters && $(PYTHON) ./runtest.py
	cd stress/atomic && $(PYTHON) ./runtest.py
	cd shared_memory && $(PYTHON) ./runtest.py
	cd device/sdmmc/ && $(PYTHON) ./runtest.py
	cd device/ps2/ && $(PYTHON) ./runtest.py
	cd device/uart && $(PYTHON) ./runtest.py
	cd libc && $(PYTHON) ./runtest.py
	cd compiler-rt && $(PYTHON) ./runtest.py
	cd whole-program && $(PYTHON) ./runtest.py --target verilator
	cd whole-program && $(PYTHON) ./runtest.py --target emulator *noverilator.*
	cd cosimulation && $(PYTHON) ./runtest.py
	cd fpga && make
	cd render && make test

fpgatest:
	cd core/cache_control/ && $(PYTHON) ./runtest.py --target fpga
	cd core/isa/ && $(PYTHON) ./runtest.py
	cd core/mmu && $(PYTHON) ./runtest.py --target fpga
	cd core/trap && $(PYTHON) ./runtest.py --target fpga
	cd fpga/memory_test && $(PYTHON) ./runtest.py --target fpga
	cd whole-program && $(PYTHON) ./runtest.py --target fpga

# For this target to work, pylint must be installed (https://www.pylint.org/)
pylint:
	PYTHONPATH=$(CURDIR) find . -iname "*.py" -exec echo {} \; -exec pylint {} \;

# For this target to work, pyflakes must be installed (https://pypi.python.org/pypi/pyflakes)
pyflakes:
	PYTHONPATH=$(CURDIR) find . -iname "*.py" -exec echo {} \; -exec pyflakes {} \;

# For this target to work, autopep8 must be installed (https://pypi.python.org/pypi/autopep8)
format:
	find . -iname "*.py" | xargs autopep8 -i
