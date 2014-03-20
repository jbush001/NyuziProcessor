# 
# Copyright 2011-2012 Jeff Bush
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

# Use this to enable writing a waveform trace file
#VERILATOR_OPTIONS+=--trace --trace-structs

# Use this to enable generating coverage files (requires SystemPerl)
#VERILATOR_OPTIONS+=--coverage

VERILATOR_OPTIONS += --assert -DENABLE_PERFORMANCE_COUNTERS -DSIMULATION -Icore -y fpga -y testbench -Wno-fatal 

verilator: FORCE
	verilator $(VERILATOR_OPTIONS) --cc testbench/verilator_tb.v --exe testbench/verilator_main.cpp
	make OPT_FAST="-O1"  -C obj_dir/ -f Vverilator_tb.mk Vverilator_tb

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: FORCE
	emacs --batch core/*.v -f verilog-batch-auto -f save-buffer
	emacs --batch fpga/*.v -f verilog-batch-auto -f save-buffer
	emacs --batch testbench/*.v  -f verilog-batch-auto -f save-buffer

clean:
	rm -rf obj_dir

FORCE:
