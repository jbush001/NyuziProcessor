#
# Use +regtrace=1 option in verilog simulator, then run the output for this script
# Creates a histogram representing the number of times a strand ends up spinning
# on a spinlock (1 spin means non-contended)
#

import re, sys

# Program addresses for locations in the spinlock routine
SPINLOCK_SYNC_LOAD = 0xb38		# u4 = mem_sync[u0]
SPINLOCK_EXIT = 0xb4c			# pc = link

transferre = re.compile('(?P<pc>[0-9A-Fa-f]+) \[st (?P<stid>\d+)\] (?P<type>[sv])\s?(?P<regid>\d+) <= (?P<value>[0-9A-Fa-f]+)')

numSpins = [ 0 for x in range(4) ]
spinHistogram = [ 0 for x in range(34) ]

for line in sys.stdin.readlines():
	got = transferre.search(line)
	if got:
		pc = int(got.group('pc'), 16)
		value = int(got.group('value'), 16)
		reg = int(got.group('regid'))
		strand = int(got.group('stid'))
		if pc == SPINLOCK_SYNC_LOAD:
			numSpins[strand] += 1
		elif pc == SPINLOCK_EXIT:
			if numSpins[strand] >= len(spinHistogram):
				spinHistogram[-1] += 1
			else:
				spinHistogram[numSpins[strand]] += 1
		
			numSpins[strand] = 0

for count in spinHistogram:
	print count	