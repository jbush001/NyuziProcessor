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
MIN_VERILATOR_VERSION=864
VERILATOR_OPTIONS=--unroll-count 512 --assert -Werror-IMPLICIT -Wwarn-syncasyncnet -Wwarn-blkseq

ifeq (${VERILATOR_TRACE},1)
	VERILATOR_OPTIONS+=--trace --trace-structs
endif

all: $(BINDIR) $(TARGET)

$(TARGET): $(BINDIR) FORCE test_verilator_version
	verilator $(VERILATOR_OPTIONS) -Icore -y testbench -y fpga/common --cc testbench/verilator_tb.sv --exe testbench/verilator_main.cpp -DSIMULATION=1 
	make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C obj_dir/ -f Vverilator_tb.mk Vverilator_tb
	cp obj_dir/Vverilator_tb $(TARGET)

core/srams.inc: $(TARGET)
	$(TARGET) +dumpmems=1 | python ../tools/misc/extract_mems.py > core/srams.inc

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: FORCE
	emacs --batch core/*.sv -f verilog-batch-auto -f save-buffer
	emacs --batch testbench/*.sv  -f verilog-batch-auto -f save-buffer
	emacs --batch fpga/common/*.sv  -f verilog-batch-auto -f save-buffer

test_verilator_version:
	@if [ $$(verilator --version | cut -f2 -d ' ' | cut -f2 -d .) -lt  $(MIN_VERILATOR_VERSION) ]; \
	then \
		echo "Verilator must be at least version 3.$(MIN_VERILATOR_VERSION). Upgrade instructions are in top level README."; \
		false; \
	fi

$(BINDIR):
	mkdir -p $(BINDIR)

clean: FORCE
	rm -rf obj_dir/*
	rm -f $(TARGET)

FORCE:
