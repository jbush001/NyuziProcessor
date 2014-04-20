VERILATOR_OPTIONS=--assert --trace --trace-structs

verilator: FORCE
	verilator $(VERILATOR_OPTIONS) -Icore -Itestbench -Wno-fatal --cc testbench/verilator_tb.v --exe testbench/verilator_main.cpp
	make OPT_FAST="-O1"  -C obj_dir/ -f Vverilator_tb.mk Vverilator_tb

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: FORCE
	emacs --batch core/*.v -f verilog-batch-auto -f save-buffer
	emacs --batch testbench/*.v  -f verilog-batch-auto -f save-buffer

FORCE:
