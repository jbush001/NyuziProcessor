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

	# test that rollback works properly.  These instructions should be
	# invalidated in the pipeline and not execute.
	runTest({},
		'''
				goto label1
				u0 = u0 + 234
				u1 = u1 + 456
				u2 = u2 + 37
				u3 = u3 + 114
		label3	u4 = u4 + 9
		done	goto done
				u5 = u5 + 12
		label1	goto label3
				u4 = u4 + 99
		''', { 'u4' : 9 })

runBranchTests()
	