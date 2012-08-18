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

#
# We validate the assembler by first assembling the test file 'assembler-test.asm'
# then disassembling it and comparing the results.  assembler-test.asm
# is manually generated to hit all of the major instruction forms
#
../../tools/assembler/assemble -o assembler-test.hex assembler-test.asm
../../tools/disassembler/disassemble assembler-test.hex > assembler-test.dis

# Strip comments out of our test program, since the disassembler won't reproduce 
# them
sed -e 's/;.*//;/^$/d' assembler-test.asm | diff -w -B -  assembler-test.dis
