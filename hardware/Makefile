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
MIN_VERILATOR_VERSION=880
VERILATOR_OPTIONS=--unroll-count 512 --assert -Werror-IMPLICIT -Wwarn-syncasyncnet -Wwarn-blkseq \
	-Icore -y testbench -y fpga/common -DSIMULATION=1 -Mdir obj

ifeq (${DUMP_WAVEFORM},1)
	VERILATOR_OPTIONS+=--trace --trace-structs
endif

all: $(BINDIR) $(TARGET)

$(TARGET): $(BINDIR) FORCE test_verilator_version
	verilator $(VERILATOR_OPTIONS) --cc testbench/verilator_tb.sv --exe testbench/verilator_main.cpp
	make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C obj/ -f Vverilator_tb.mk Vverilator_tb
	cp obj/Vverilator_tb $(TARGET)

fpgalint:
	verilator $(VERILATOR_OPTIONS) --lint-only fpga/de2-115/de2_115_top.sv

core/srams.inc: $(TARGET)
	$(TARGET) +dumpmems | ../tools/misc/extract_mems.py > core/srams.inc

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos:
	emacs --eval '(setq-default indent-tabs-mode nil)' \
		--eval '(setq-default verilog-typedef-regexp "_t$$")' \
		--eval '(setq-default verilog-auto-reset-widths `unbased)' \
		--eval '(setq-default verilog-auto-inst-param-value t)' \
		--eval '(setq-default verilog-library-directories `("$(CURDIR)/core" "$(CURDIR)/testbench" "$(CURDIR)/fpga/common" "."))' \
		--batch core/*.sv testbench/*.sv fpga/common/*.sv fpga/de2-115/*.sv \
		-f verilog-batch-auto -f save-buffer

test_verilator_version:
	@if [ $$(verilator --version | cut -f2 -d ' ' | cut -f2 -d .) -lt  $(MIN_VERILATOR_VERSION) ]; \
	then \
		echo "Verilator must be at least version 3.$(MIN_VERILATOR_VERSION). Upgrade instructions are in top level README."; \
		false; \
	fi

$(BINDIR):
	mkdir -p $(BINDIR)

clean: FORCE
	rm -rf obj/*
	rm -f $(TARGET)

FORCE:
