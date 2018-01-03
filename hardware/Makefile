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

BUILDDIR=../build
VCSBUILD=$(BUILDDIR)/vcsbuild.pl

BINDIR=../bin
TARGET=$(BINDIR)/verilator_model
MIN_VERILATOR_VERSION=918
VERILATOR_OPTIONS=--unroll-count 512 --assert \
	-Wall -Wno-unused -Wno-pinconnectempty -Wno-undriven -Wno-declfilename \
	-Icore -y testbench -y fpga/common -DSIMULATION=1 -Mdir obj

# If you set DUMP_WAVEFORM in the environment when running make, the resulting
# simulator executable will generating a .vcd file that can be read by a
# waveform viewer like gtkwave.
ifeq (${DUMP_WAVEFORM},1)
	VERILATOR_OPTIONS+=--trace --trace-structs
endif

all: $(BINDIR) $(TARGET)

$(TARGET): $(BINDIR) test_verilator_version
	verilator $(VERILATOR_OPTIONS) --cc testbench/soc_tb.sv --exe testbench/verilator_main.cpp testbench/jtag_socket.cpp
	make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C obj/ -f Vsoc_tb.mk Vsoc_tb
	cp obj/Vsoc_tb $(TARGET)

vcsbuild:
	$(VCSBUILD)

# Verilator usually doesn't compile the FPGA project files, but this
# will run it in lint-only mode to catch syntax errors or mismatches
# introduced by changes in the core.
fpgalint:
	verilator $(VERILATOR_OPTIONS) --lint-only fpga/de2-115/de2_115_top.sv

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module
# installed.
autos:
	emacs --eval '(setq-default indent-tabs-mode nil)' \
		--eval '(setq-default verilog-typedef-regexp "_t$$")' \
		--eval '(setq-default verilog-auto-reset-widths `unbased)' \
		--eval '(setq-default verilog-auto-inst-param-value t)' \
		--eval '(setq-default verilog-library-directories `("$(CURDIR)/core" "$(CURDIR)/testbench" "$(CURDIR)/fpga/common" "."))' \
		--batch core/*.sv testbench/*.sv fpga/common/*.sv fpga/de2-115/*.sv \
		-f verilog-batch-auto -f save-buffer

# Bail if verilator is too old.
test_verilator_version:
	@if [ $$(verilator --version | cut -f2 -d ' ' | cut -f2 -d .) -lt  $(MIN_VERILATOR_VERSION) ]; \
	then \
		echo "Verilator must be at least version 3.$(MIN_VERILATOR_VERSION). Upgrade instructions are in top level README."; \
		false; \
	fi

# This is not used by the verilator simulator or FPGA projects, but is
# theoretically useful for environments that use a separate memory compiler.
core/srams.inc: $(TARGET)
	$(TARGET) +dumpmems | ../tools/misc/extract_mems.py > core/srams.inc

$(BINDIR):
	mkdir -p $(BINDIR)

clean:
	rm -rf obj/*
	rm -f $(TARGET)
	rm -rf $(BUILDDIR)/csrc $(BUILDDIR)/simv.daidir
	rm -f $(BUILDDIR)/simv
