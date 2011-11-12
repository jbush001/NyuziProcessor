import re, sys

def makeInitializer(identifier):
	print '\t\t' + identifier + ' = 0;'

form1 = re.compile('reg\s*(?P<name>[a-zA-Z][a-zA-Z_0-9]*)')
form2 = re.compile('reg\s*\[[^\]]*\]\s*(?P<name>[a-zA-Z][a-zA-Z_0-9]*)')

for line in sys.stdin:
	found = form1.search(line)
	if found != None:
		makeInitializer(found.group('name'))
	else:
		found = form2.search(line)
		if found != None:
			makeInitializer(found.group('name'))
			
