#!/usr/bin/env python
# 
# Copyright (C) 2011-2015 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 


#
# Read a Wavefront .OBJ file and convert it into a flat file that can be read
# by the viewer program
#

import sys
import os
import re
import subprocess
import struct
import math
import tempfile

NUM_MIP_LEVELS=4

# This is the final output of the parsing stage
textureList = []	# (width, height, data)
meshList = []		# (texture index, vertex list, index list)

materialNameToTextureIdx = {}
textureFileToTextureIdx = {}

size_re1 = re.compile('Geometry: (?P<width>\d+)x(?P<height>\d+)') # JPEG
size_re2 = re.compile('PNG width: (?P<width>\d+), height: (?P<height>\d+)') # PNG
def read_image_file(filename, resizeToWidth = None, resizeToHeight = None):
	width = None
	height = None
	handle, temppath = tempfile.mkstemp(suffix='.bin')
	os.close(handle)

	args = ['convert', '-debug', 'all']
	if resizeToWidth:
		args += [ '-resize', str(resizeToWidth) + 'x' + str(resizeToHeight) + '^' ]

	args += [filename, 'rgba:' + temppath]
	p = subprocess.Popen(args, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
	out, err = p.communicate()

	# This is a kludge.  Try to determine width and height from debug information
	for line in err.split('\n'):
		got = size_re1.search(line)
		if got:
			width = int(got.group('width'))
			height = int(got.group('height'))
		else:
			got = size_re2.search(line)
			if got:
				width = int(got.group('width'))
				height = int(got.group('height'))

	
	if width == None or height == None:
		raise Exception('Could not determine dimensions of texture ' + filename)
			
	with open(temppath, 'rb') as f:
		textureData = f.read()

	os.unlink(temppath)
		
	return (width, height, textureData)

def read_texture(filename):
	print 'read texture', filename
	width, height, data = read_image_file(filename)

	# Read in lower mip levels
	for level in range(1, NUM_MIP_LEVELS + 1):
		_, _, sub_data = read_image_file(filename, width >> level, height >> level)
		data += sub_data
		
	return width, height, data

def read_mtl_file(filename):
	global textureList, materialNameToTextureIdx

	print 'read material file', filename
	
	currentName = ''
	currentFile = ''
	with open(filename) as f:
		for line in f:
			if line[0] == '#' or line.strip() == '':
				continue
			
			fields = [s for s in line.strip().split(' ') if s]
			if fields[0] == 'newmtl':
				currentName = fields[1]
				materialNameToTextureIdx[fields[1]] = -1
			elif fields[0] == 'map_Kd':
				textureFile = fields[1]
				if textureFile in textureFileToTextureIdx:
					# We've already used this texture, just tag the same ID
					materialNameToTextureIdx[currentName] = textureFileToTextureIdx[textureFile]
				else:
					# load a new texture
					materialNameToTextureIdx[currentName] = len(textureList)
					textureFileToTextureIdx[textureFile] = len(textureList)
					textureList.append(read_texture(os.path.dirname(filename) + '/' + fields[1].replace('\\', '/')))
					
def compute_normal(vertex1, vertex2, vertex3):
	# Vector 1
	ax = vertex2[0] - vertex1[0]
	ay = vertex2[1] - vertex1[1]
	az = vertex2[2] - vertex1[2]

	# Vector 2
	bx = vertex3[0] - vertex1[0]
	by = vertex3[1] - vertex1[1]
	bz = vertex3[2] - vertex1[2]
	
	# Cross product
	cx = ay * bz - az * by
	cy = az * bx - ax * bz
	cz = ax * by - ay * bx
	
	# Normalize
	mag = math.sqrt(cx * cx + cy * cy + cz * cz)
	if mag == 0:
		return (0, 0, 0)
	
	return (cx / mag, cy / mag, cz / mag)
	
def zero_to_one_based_index(x):
	return x + 1 if x < 0 else x - 1

def read_obj_file(filename):
	global meshList
	
	vertexPositions = []
	textureCoordinates = []
	normals = []
	combinedVertices = []
	vertexToIndex = {}
	triangleIndexList = []
	currentMaterial = None
	currentTextureId = -1

	with open(filename, 'r') as f:
		for line in f:
			if line[0] == '#' or line.strip() == '':
				continue
			
			fields = [s for s in line.strip().split(' ') if s]
			if fields[0] == 'v':
				vertexPositions.append((float(fields[1]), float(fields[2]), float(fields[3])))
			elif fields[0] == 'vt':
				textureCoordinates.append((float(fields[1]), float(fields[2])))
			elif fields[0] == 'vn':
				normals.append((float(fields[1]), float(fields[2]), float(fields[3])))
			elif fields[0] == 'f':
				# The OBJ file references vertexPositions and texture coordinates independently.
				# They must be paired in our implementation. Build a new vertex list that
				# combines those and generate an index list into that.

				# Break the strings 'vertexIndex/textureIndex' into a list and
				# convert to 0 based array (OBJ is 1 based)
				parsedIndices = []
				for indexTuple in fields[1:]:
					parsedIndices.append([zero_to_one_based_index(int(x)) if x != '' else '' for x in indexTuple.split('/')])

				if len(parsedIndices[0]) < 3:
					# This file does not contain normals.  Generate a face normal
					# that we will substitute.
					# XXX this isn't perfect because the vertex normal should be the
					# combination of all face normals, but it's good enough for
					# our purposes.
					faceNormal = compute_normal(vertexPositions[parsedIndices[0][0]], 
						vertexPositions[parsedIndices[1][0]],
						vertexPositions[parsedIndices[2][0]])
				else:
					faceNormal = None

				# Create a new vertex array that combines the attributes
				polygonIndices = []
				for indices in parsedIndices:
					vertexAttrs = vertexPositions[indices[0]]
					if len(indices) > 1 and indices[1]:
						vertexAttrs += textureCoordinates[indices[1]]
					else:
						vertexAttrs += ( 0, 0 )
						
					if faceNormal:
						vertexAttrs += faceNormal
					else:
						vertexAttrs += normals[indices[2]]
					
					if vertexAttrs not in vertexToIndex:
						vertexToIndex[vertexAttrs] = len(combinedVertices)
						combinedVertices += [ vertexAttrs ]
				
					polygonIndices += [ vertexToIndex[vertexAttrs] ]

				# faceList is made up of polygons. Convert to triangles
				for index in range(1, len(polygonIndices) - 1):
					triangleIndexList += [ polygonIndices[0], polygonIndices[index], polygonIndices[index + 1] ]
			elif fields[0] == 'usemtl':
				# Switch material
				newTextureId = materialNameToTextureIdx[fields[1]]
				if newTextureId != currentTextureId:
					if triangleIndexList:
						# State change, emit current primitives and clear the current combined list
						meshList += [ (currentTextureId, combinedVertices, triangleIndexList) ]
						combinedVertices = []
						vertexToIndex = {}
						triangleIndexList = []
					currentTextureId = newTextureId
			elif fields[0] == 'mtllib':
				read_mtl_file(os.path.dirname(filename) + '/' + fields[1])

		if triangleIndexList != []:
			meshList += [ (currentTextureId, combinedVertices, triangleIndexList) ]

def print_stats():
	totalTriangles = 0
	totalVertices = 0
	minx = float('Inf')
	maxx = float('-Inf')
	miny = float('Inf')
	maxy = float('-Inf')
	minz = float('Inf')
	maxz = float('-Inf')
	
	for _, vertices, indices in meshList:
		totalTriangles += len(indices) / 3
		totalVertices += len(vertices)
		for x, y, z, _, _, _, _, _ in vertices:
			minx = min(x, minx)
			miny = min(y, miny)
			minz = min(z, minz)
			maxx = max(x, maxx)
			maxy = max(y, maxy)
			maxz = max(z, maxz)

	print 'meshes', len(meshList) 
	print 'triangles', totalTriangles
	print 'vertices', totalVertices
	print 'scene bounds'
	print '  x', minx, maxx
	print '  y', miny, maxy
	print '  z', minz, maxz

def align(addr, alignment):
	return int((addr + alignment - 1) / alignment) * alignment

def write_resource_file(filename):
	global textureList
	global meshList
	
	currentDataOffset = 12 + len(textureList) * 12 + len(meshList) * 16 # Skip header
	currentHeaderOffset = 12

	with open(filename, 'wb') as f:
		# Write textures
		for width, height, data in textureList:
			# Write file header
			f.seek(currentHeaderOffset)
			f.write(struct.pack('iihh', currentDataOffset, NUM_MIP_LEVELS, width, height))
			currentHeaderOffset += 12

			# Write data
			f.seek(currentDataOffset)
			f.write(data)
			currentDataOffset = align(currentDataOffset + len(data), 4)
			
		# Write meshes
		for textureIdx, vertices, indices in meshList:
			currentDataOffset = align(currentDataOffset, 4)

			# Write file header
			f.seek(currentHeaderOffset)
			f.write(struct.pack('iiii', currentDataOffset, textureIdx, len(vertices), len(indices)))
			currentHeaderOffset += 16

			# Write data
			f.seek(currentDataOffset)
			for vert in vertices:
				for val in vert:
					f.write(struct.pack('f', val))
					currentDataOffset += 4
				
			for index in indices:
				f.write(struct.pack('I', index))
				currentDataOffset += 4

		# Write file header
		f.seek(0)
		f.write(struct.pack('I', currentDataOffset)) # total size
		f.write(struct.pack('I', len(textureList))) # num textures
		f.write(struct.pack('I', len(meshList))) # num meshes
		
		print 'wrote', filename

# Main
if len(sys.argv) < 2:
	print 'enter the name of a .OBJ file'
	sys.exit(1)

read_obj_file(sys.argv[1])
print_stats()
write_resource_file('resource.bin')



	





