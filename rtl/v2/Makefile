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

VERILATOR_OPTIONS=--assert -Werror-IMPLICIT
#VERILATOR_OPTIONS+=--trace --trace-structs

verilator: FORCE
	verilator $(VERILATOR_OPTIONS) -Icore -Itestbench -Wno-fatal --cc testbench/verilator_tb.v --exe testbench/verilator_main.cpp
	make OPT_FAST="-O1"  -C obj_dir/ -f Vverilator_tb.mk Vverilator_tb

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: FORCE
	emacs --batch core/*.v -f verilog-batch-auto -f save-buffer
	emacs --batch testbench/*.v  -f verilog-batch-auto -f save-buffer

FORCE:
