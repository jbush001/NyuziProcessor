
REQUEST_TYPES = [
	'PCI_LOAD',
	'PCI_STORE',
	'PCI_FLUSH',
	'PCI_INVALIDATE',
	'PCI_LOAD_SYNC',
	'PCI_STORE_SYNC'
]

RESPONSE_TYPES = [
	'CPI_LOAD_ACK',
	'CPI_STORE_ACK',
	'CPI_WRITE_INVALIDATE'
]

class L2CacheInterfaceAnnotator:
	def __init__(self):
		pass
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('pipeline_sim.pci_valid') == 1:
			# XXX and vcd.getNetValue('pipeline_sim.pci_ack') == 1:
			type = vcd.getNetValue('pipeline_sim.pci_op')
			response = REQUEST_TYPES[type]
			response += ' str ' + str(vcd.getNetValue('pipeline_sim.pci_strand'))
			response += ' unit ' + str(vcd.getNetValue('pipeline_sim.pci_unit'))
			response += ' adr ' + hex(vcd.getNetValue('pipeline_sim.pci_address'))
			if type == 1 or type == 5:
				response += ' m ' + hex(vcd.getNetValue('pipeline_sim.pci_mask'))
				response += ' d ' + hex(vcd.getNetValue('pipeline_sim.pci_data'))
				
			print response
		
		if vcd.getNetValue('pipeline_sim.cpi_valid') == 1:
			type = vcd.getNetValue('pipeline_sim.cpi_op')
			response = RESPONSE_TYPES[type]
			response += ' str ' + str(vcd.getNetValue('pipeline_sim.cpi_strand'))
			response += ' unit ' + str(vcd.getNetValue('pipeline_sim.cpi_unit'))
			response += ' data ' + hex(vcd.getNetValue('pipeline_sim.cpi_data'))
			print response		

class SystemMemoryInterface:
	def __init__(self):
		self.burstStart = None
		self.burstIsWrite = False
		self.burstLength = 0
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('pipeline_sim.l2_cache.request_o'):
			if self.burstStart == None:
				self.burstStart = vcd.getNetValue('pipeline_sim.l2_cache.addr_o')
				self.burstLength = 0
				self.burstIsWrite = vcd.getNetValue('pipeline_sim.l2_cache.write_o')
			else:
				self.burstLength += 1
		elif self.burstStart != None:
			print '%s burst addr 0x%08x length %d' % ("write" if self.burstIsWrite else "read",
				self.burstStart, self.burstLength)
			self.burstStart = None

class L2LineUpdate:
	def __init__(self):
		pass
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('pipeline_sim.l2_cache.wr_update_l2_data'):
			print 'update cache index %08x <= %0128x' % (
				vcd.getNetValue('pipeline_sim.l2_cache.wr_cache_write_index'),
				vcd.getNetValue('pipeline_sim.l2_cache.wr_update_data'))
			
class L2DirtyBits:
	def __init__(self):
		pass
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.tag_pci_valid'):
			#isDirtying = vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.is_dirtying')
			op = vcd.getNetValue('pipeline_sim.l2_cache.tag_pci_op')
			isDirtying = op == 1 or op == 5
			if vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.tag_has_sm_data'):
				print 'mark set %d way %d %s' % (
					vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.requested_l2_set'),
					vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.tag_sm_fill_l2_way'),
					'dirty' if isDirtying else 'clean')
			elif vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.cache_hit') and isDirtying:
				print 'mark set %d way %d dirty' % (
					vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.requested_l2_set'),
					vcd.getNetValue('pipeline_sim.l2_cache.l2_cache_dir.hit_l2_way'))
	