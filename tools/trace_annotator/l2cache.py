
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

class L2CacheAnnotator:
	def __init__(self):
		pass
		
	def clockTransition(self, vcd):
		if vcd.getNetValue('pipeline_sim.pci_valid') == 1:
			# XXX and vcd.getNetValue('pipeline_sim.pci_ack') == 1:
			type = vcd.getNetValue('pipeline_sim.pci_op')
			response = REQUEST_TYPES[type]
			response += ' str ' + str(vcd.getNetValue('pipeline_sim.pci_strand'))
			response += ' adr ' + hex(vcd.getNetValue('pipeline_sim.pci_address'))
			if type == 1 or type == 5:
				response += ' m ' + hex(vcd.getNetValue('pipeline_sim.pci_mask'))
				response += ' d ' + hex(vcd.getNetValue('pipeline_sim.pci_data'))
				
			print response
		
		if vcd.getNetValue('pipeline_sim.l2_cache.cpi_valid') == 1:
			type = vcd.getNetValue('pipeline_sim.cpi_op')
			response = RESPONSE_TYPES[type]
			response += ' st ' + hex(vcd.getNetValue('pipeline_sim.cpi_strand'))
			response += ' data ' + hex(vcd.getNetValue('pipeline_sim.cpi_data'))
			print response		

