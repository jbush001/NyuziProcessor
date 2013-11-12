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


BASEDIR=../..
VERILATOR=../../rtl/obj_dir/Vverilator_tb
SRCS=main.asm rasterize.asm geometry.asm fill.asm runtime.asm

program.hex: $(SRCS)
	$(BASEDIR)/tools/assembler/assemble -o program.hex $(SRCS)

vsim: program.hex FORCE
	rm -f vsim-fb.bin vsim.bmp
	$(VERILATOR) +bin=program.hex +simcycles=1000000 +memdumpbase=FC000 +memdumplen=4000 +memdumpfile=vsim-fb.bin 
	$(BASEDIR)/tools/mkbmp/mkbmp vsim-fb.bin vsim.bmp 64 64
	
csim: program.hex FORCE
	rm -f csim-fb.bin csim.bmp
	$(BASEDIR)/tools/simulator/iss -d csim-fb.bin,FC000,4000 program.hex 
	$(BASEDIR)/tools/mkbmp/mkbmp csim-fb.bin csim.bmp 64 64
	
FORCE:

