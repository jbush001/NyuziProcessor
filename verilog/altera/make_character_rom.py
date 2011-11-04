#
# Given a text file containing ASCII art font definitions, convert it to
# a verilog character ROM.
#

import sys, os

def isIndex(line):
	return (line[0] >= '0' and line[0] <= '9') or (line[0] >= 'a' and line[0] <= 'f') \
		or (line[0] >= 'A' and line[0] <= 'F')
	
def isBlank(line):
	for ch in line:
		if ch != ' ' and ch != '\t' and ch != '\r' and ch != '\n':
			return False
			
	return True

# Left justified.  If codes are missing, they will be filled with zeroes
def decodeLine(line):
	mask = 0x80
	value = 0
	for ch in line:
		if ch != '.':
			value |= mask
			
		mask >>= 1
		
	return value

characterRom = [0 for x in range(128 * 8)]
currentAsciiCode = 0
currentCharLine = 0
lastLineWasBlank = False

for line in open(sys.argv[1]):
	if isIndex(line):
		currentAsciiCode = int(line, 16)
		currentCharLine = 0
	elif isBlank(line):
		if not lastLineWasBlank:
			currentAsciiCode += 1
			lastLineWasBlank = True
			
		currentCharLine = 0
	else:
		lastLineWasBlank = False
		characterRom[currentAsciiCode * 8 + currentCharLine] = decodeLine(line)
		currentCharLine += 1

print '''module character_rom(
	input[9:0] code_i,
	output reg[7:0] line_o);

	initial
	begin
		line_o = 0;
	end

	always @*
	begin
		case (code_i)'''

for index, bitMask in enumerate(characterRom):
	if bitMask != 0:
		print "\t\t\t11'h%04x: line_o = 8'h%02x" % (index, bitMask)
	
print '''\t\t\tdefault: line_o = 8'h00

		endcase
	end
endmodule
'''