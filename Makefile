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



all:
	cd tools/assembler && make
	cd tools/disassembler && make
	cd tools/emulator && make
	cd tools/mkbmp && make
	cd verilog && make
	
clean:
	cd tools/assembler && make clean
	cd tools/disassembler && make clean
	cd tools/emulator && make clean
	cd tools/mkbmp && make clean
	cd verilog && make clean

