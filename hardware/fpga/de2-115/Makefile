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


output_files/fpga_target.sof: FORCE
	quartus_map fpga_target
	quartus_fit fpga_target
	quartus_asm fpga_target
	quartus_sta fpga_target
	
program: 
	quartus_pgm -c USB-Blaster -m jtag -o "P;output_files/fpga_target.sof"

netlist:
	quartus_eda --write_settings_files=off fpga_target --format=verilog --tool=modelsim --simulation=on

FORCE:
