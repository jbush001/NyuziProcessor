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


class RegisterAnnotator:
	def __init__(self):
		self.oldPc = 0
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('simulator_top.core.pipeline.wb_has_writeback'):
			regIndex = vcd.getNetValue('simulator_top.core.pipeline.wb_writeback_reg')
			strand = regIndex / 32
			reg = regIndex % 32
		
			if vcd.getNetValue('simulator_top.core.pipeline.wb_writeback_is_vector'):
				print '%08x [st %d] v%d{%04x} <= %0128x' % (self.lastPc - 4, strand, reg,
					vcd.getNetValue('simulator_top.core.pipeline.wb_writeback_mask'),
					vcd.getNetValue('simulator_top.core.pipeline.wb_writeback_value'))
			else:
				print '%08x [st %d] s%d <= %08x' % (self.lastPc - 4, strand, reg,
					vcd.getNetValue('simulator_top.core.pipeline.wb_writeback_value') & 0xffffffff)

		self.lastPc = vcd.getNetValue('simulator_top.core.pipeline.ma_pc')
