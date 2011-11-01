from runcase import *

def runBranchTests():
	# goto
	code = '''		goto label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 1 }, code, { 'u0' : 12 })
	
	# PC destination
#	code = '''		addi 	pc, r0, 8
#		loop1		goto loop1		
#					addi 	u1, r0, 12
#		loop2		goto loop2'''
#	runTest({ 'u1' : 1 }, code, { 'u1' : 12 })

	# bzero, branch not taken
	code = '''		bzero u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 0 }, code, { 'u0' : 12 })
		
	# bzero, branch taken
	code = '''		bzero u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 1 }, code, { 'u0' : 5 })
		

	# bnzero, branch not taken
	code = '''		bnzero 	u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 0 }, code, { 'u0' : 5 })
		
	# bnzero, branch taken
	code = '''		bnzero 	u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 1 }, code, { 'u0' : 12 })

	# ball, branch not taken (some bits set)
	code = '''		ball u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 1 }, code, { 'u0' : 5 })

	# ball, branch not taken (no bits set)
	code = '''		ball u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 0 }, code, { 'u0' : 5 })

	# ball, branch taken (all bits set)
	code = '''		ball u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 0xffff }, code, { 'u0' : 12 })

	# ball, branch taken (some high bits set)
	code = '''		ball u1, label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2'''
	runTest({ 'u1' : 0x20ffff }, code, { 'u0' : 12 })



runBranchTests()
	