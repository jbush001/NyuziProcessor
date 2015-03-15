# 
# Copyright 2011-2015 Jeff Bush
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


BINDIR=../bin
TARGET=$(BINDIR)/verilator_model

# Fixes errors that occur when a larger number of cores used
VERILATOR_OPTIONS=--unroll-count 128  

# Uncomment this to write out a .VCD waveform file
#VERILATOR_OPTIONS=--trace --trace-structs

all: $(BINDIR) $(TARGET)

$(TARGET): $(BINDIR) FORCE
	verilator $(VERILATOR_OPTIONS) -Icore -y testbench -y fpga -Wno-fatal --assert -Werror-IMPLICIT --cc testbench/verilator_tb.sv --exe testbench/verilator_main.cpp -DSIMULATION=1 
	make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C obj_dir/ -f Vverilator_tb.mk Vverilator_tb
	cp obj_dir/Vverilator_tb $(TARGET)

core/srams.inc: $(TARGET)
	$(TARGET) +dumpmems=1 | python ../tools/misc/extract_mems.py > core/srams.inc

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: FORCE
	emacs --batch core/*.sv -f verilog-batch-auto -f save-buffer
	emacs --batch testbench/*.sv  -f verilog-batch-auto -f save-buffer
	emacs --batch fpga/*.sv  -f verilog-batch-auto -f save-buffer

$(BINDIR):
	mkdir -p $(BINDIR)

clean: FORCE
	rm -rf obj_dir/*
	rm -f $(TARGET)

FORCE:
