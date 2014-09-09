# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

BINDIR=../bin
TARGET=$(BINDIR)/verilator_model

#VERILATOR_OPTIONS=--trace --trace-structs

all: $(BINDIR) $(TARGET)

$(TARGET): $(BINDIR) FORCE
	verilator $(VERILATOR_OPTIONS) -Icore -y testbench -y fpga -Wno-fatal --assert -Werror-IMPLICIT --cc testbench/verilator_tb.v --exe testbench/verilator_main.cpp -DSIMULATION=1 
	make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C obj_dir/ -f Vverilator_tb.mk Vverilator_tb
	cp obj_dir/Vverilator_tb $(TARGET)

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: FORCE
	emacs --batch core/*.v -f verilog-batch-auto -f save-buffer
	emacs --batch testbench/*.v  -f verilog-batch-auto -f save-buffer
	emacs --batch fpga/*.v  -f verilog-batch-auto -f save-buffer

$(BINDIR):
	mkdir -p $(BINDIR)

clean: FORCE
	rm -rf obj_dir/*
	rm -f $(TARGET)

FORCE:
