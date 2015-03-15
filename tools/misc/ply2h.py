# 
# Copyright 2011-2015 Jeff Bush
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


#
# Convert a Stanford .PLY model file into a C header file with a list of triangle
# indices
#

import sys

STATE_HEADER = 0
STATE_VERTICES = 1
STATE_FACES = 2

state = STATE_HEADER
numVertices = -1
numFaces = -1
totalTriangles = 0

if len(sys.argv) > 1:
	prefix = sys.argv[1]
else:
	prefix = ''

for line in sys.stdin.readlines():
	fields = [ field.strip() for field in line.split(' ') ]
	if state == STATE_HEADER:
		if fields[0] == 'element':
			if fields[1] == 'vertex':
				numVertices = int(fields[2])
			elif fields[1] == 'face':
				numFaces = int(fields[2])
			else:
				raise Exception('Unknown element type ' + fields[2])
		elif fields[0] == 'end_header':
			if numVertices == -1 or numFaces == -1:
				raise Exception('Unknown number of vertices or elements')
			
			state = STATE_VERTICES
			print 'const int kNum' + prefix + 'Vertices = ' + str(numVertices) + ';'
			print 'const float k' + prefix + 'Vertices[] = {'
	elif state == STATE_VERTICES:
		outline = '\t'
		for x in fields:
			outline += x + ', '
		
		print outline
		numVertices -= 1
		if numVertices == 0:
			state = STATE_FACES
			print '};\n'
			print 'const int k' + prefix + 'Indices[] = {'
	elif state == STATE_FACES:
		numIndices = int(fields[0])
		if numIndices < 3:
			raise Exception('bad number of indices')

		for x in range(1, numIndices - 1):
			print '\t' + fields[1] + ', ' + fields[x + 1] + ', ' + fields[x + 2]  + ','
			totalTriangles += 1


		numFaces -= 1
		if numFaces == 0:
			print '};\n'
			print 'const int kNum' + prefix + 'Indices = ' + str(totalTriangles * 3) + ';\n'
			break

