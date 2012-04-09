//
// L2 cache interface constants
//

`define PCI_LOAD  3'b000
`define PCI_STORE 3'b001
`define PCI_FLUSH 3'b010
`define PCI_INVALIDATE 3'b011
`define PCI_LOAD_SYNC 3'b100
`define PCI_STORE_SYNC 3'b101

`define CPI_LOAD_ACK 2'b00
`define CPI_STORE_ACK 2'b01
`define CPI_WRITE_INVALIDATE 2'b10