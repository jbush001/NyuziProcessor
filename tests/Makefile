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

#
# The following tests are not run as part of the 'test' target:
#
#  stress/mmu/    - Takes a while to run, skipped to keep continuous integration
#                   tests quick.
#  lldb/          - LLDB is not installed in the CI environment's container.
#  core/multicore/- Requires modifying hardware model to have 8 cores and rebuilding.
#  csmith/        - Running on a 64-bit host produces different checksums than the
#                   program running on Nyuzi because of differences in native
#                   word width. Can still be useful to detect compiler crashes.
#  fail/          - These test cases validate the test harness itself and are meant
#                   to produce failure results.
#  float/         - Floating point conformance tests. There are still bugs in the
#                   hardware implementation that need to be fixed, and there are
#                   tweaks required to the test vectors to find canonical values
#                   where the spec is lenient.
#  fpga/          - These only run in the FPGA environment and validate things
#                   specific to the dev board (the test target only assembles them)
#  kernel/
#     crash/      - Intermittently timing out, potentially because of a bug
#     globalinit/
#     hello/
#     panic/
#     user_copy_fault/
#     initdata/
#
#     multiprocess/ - These do not have automated harnesses and are not easy to
#     threads/        automate for a number of reasons.
#     vga/
#  render/          - These only run under the emulator (they support verilator, but
#                     they take a long time to run)
#

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
	cd compiler && USE_VERILATOR=1 $(PYTHON) ./runtest.py
	cd compiler && $(PYTHON) ./runtest.py *noverilator.*
	cd cosimulation && $(PYTHON) ./runtest.py
	cd fpga && make
	cd render && make test

# For this target to work, pylint must be installed (https://www.pylint.org/)
pylint:
	PYTHONPATH=$(CURDIR) find . -iname "*.py" -exec echo {} \; -exec pylint {} \;

# For this target to work, pyflakes must be installed (https://pypi.python.org/pypi/pyflakes)
pyflakes:
	PYTHONPATH=$(CURDIR) find . -iname "*.py" -exec echo {} \; -exec pyflakes {} \;

# For this target to work, autopep8 must be installed (https://pypi.python.org/pypi/autopep8)
format:
	find . -iname "*.py" | xargs autopep8 -i
