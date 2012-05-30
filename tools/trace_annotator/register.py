
class RegisterAnnotator:
	def __init__(self):
		self.oldPc = 0
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('pipeline_sim.core.pipeline.wb_has_writeback'):
			regIndex = vcd.getNetValue('pipeline_sim.core.pipeline.wb_writeback_reg')
			strand = regIndex / 32
			reg = regIndex % 32
		
			if vcd.getNetValue('pipeline_sim.core.pipeline.wb_writeback_is_vector'):
				print '%08x [st %d] v%d{%04x} <= %0128x' % (self.lastPc - 4, strand, reg,
					vcd.getNetValue('pipeline_sim.core.pipeline.wb_writeback_mask'),
					vcd.getNetValue('pipeline_sim.core.pipeline.wb_writeback_value'))
			else:
				print '%08x [st %d] s%d <= %08x' % (self.lastPc - 4, strand, reg,
					vcd.getNetValue('pipeline_sim.core.pipeline.wb_writeback_value') & 0xffffffff)

		self.lastPc = vcd.getNetValue('pipeline_sim.core.pipeline.ma_pc')
