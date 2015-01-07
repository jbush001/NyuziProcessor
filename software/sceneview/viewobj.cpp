// 
// Copyright (C) 2011-2015 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#include <stdio.h>
#include <RenderContext.h>
#include <Surface.h>
#include "TextureShader.h"


struct FileHeader
{
	unsigned int fileSize;
	unsigned int numTextures;
	unsigned int numMeshes;
};

struct TextureEntry
{
	unsigned int offset;
	unsigned int mipLevels;
	short width;
	short height;
};

struct MeshEntry
{
	unsigned int offset;
	unsigned int textureId;
	unsigned int numVertices;
	unsigned int numIndices;
};

const int kAttrsPerVertex = 8;
const int kBlockSize = 512;
static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

void readBlock(unsigned int blockAddress, void *out)
{
	int i;
	unsigned int *ptr = (unsigned int*) out;
	
	REGISTERS[0x30 / 4] = blockAddress;
	for (i = 0; i < kBlockSize / 4; i++)
		*ptr++ = REGISTERS[0x34 / 4];
}

char *readResourceFile()
{
	char tmp[kBlockSize];
	unsigned int fileSize;
	char *resourceData;

	// Read the first block to determine how large the rest of the file is.
	readBlock(0, tmp);
	fileSize = ((FileHeader*) tmp)->fileSize;

	printf("reading resource file, %d bytes\n", fileSize);
	
	resourceData = (char*) malloc(fileSize + kBlockSize);
	memcpy(resourceData, tmp, kBlockSize);
	for (int i = 1, len=(fileSize + kBlockSize - 1) / kBlockSize; i < len; i++)
		readBlock(i * kBlockSize, resourceData + i * kBlockSize);

	return resourceData;
}

int main()
{
	// Set up resource data
	char *resourceData = readResourceFile();
	const FileHeader *resourceHeader = (FileHeader*) resourceData;
	const TextureEntry *texHeader = (TextureEntry*)(resourceData + sizeof(FileHeader));
	const MeshEntry *meshHeader = (MeshEntry*)(resourceData + sizeof(FileHeader) + resourceHeader->numTextures
		* sizeof(TextureEntry));
	Texture **textures = new Texture*[resourceHeader->numTextures];

	printf("%d textures %d meshes\n", resourceHeader->numTextures, resourceHeader->numMeshes);

	// Create texture objects
	for (unsigned int textureIndex = 0; textureIndex < resourceHeader->numTextures; textureIndex++)
	{
		textures[textureIndex] = new Texture();
		textures[textureIndex]->enableBilinearFiltering(true);
		int offset = texHeader[textureIndex].offset;
		for (unsigned int mipLevel = 0; mipLevel < texHeader[textureIndex].mipLevels; mipLevel++)
		{
			int width = texHeader[textureIndex].width >> mipLevel;
			int height = texHeader[textureIndex].height >> mipLevel;
			Surface *surface = new Surface(width, height, resourceData + offset);
			textures[textureIndex]->setMipSurface(mipLevel, surface);
			offset += width * height * 4;
		}
	}
	
	// Set up render state
	RenderContext *context = new RenderContext(0x1000000);
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(FB_WIDTH, FB_HEIGHT, (void*) 0x200000);
	Surface *zBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setZBuffer(zBuffer);
	context->bindTarget(renderTarget);
	context->enableZBuffer(true);
	context->bindShader(new TextureVertexShader(), new TexturePixelShader());
	context->setClearColor(0.52, 0.80, 0.98);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);

	TextureUniforms uniforms;
	uniforms.fLightDirection = Vec3(-1, -0.5, 1).normalized();
	uniforms.fDirectional = 0.3f;		
	uniforms.fAmbient = 0.7f;
	float theta = 0.0;

	for (int frame = 0; ; frame++)
	{
		Matrix modelViewMatrix = Matrix::lookAt(Vec3(0, 3, 0), Vec3(cos(theta), 3, sin(theta)), Vec3(0, 1, 0));
		theta = theta + M_PI / 8;
		if (theta > M_PI * 2)
			theta -= M_PI * 2;
		
		uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
		uniforms.fNormalMatrix = modelViewMatrix.upper3x3();
		
		for (unsigned int i = 0; i < resourceHeader->numMeshes; i++)
		{
			const MeshEntry &entry = meshHeader[i];

			if (entry.textureId != 0xffffffff)
			{
				assert(entry.textureId < resourceHeader->numTextures);
				context->bindTexture(0, textures[entry.textureId]);
				uniforms.fHasTexture = true;
			}
			else
				uniforms.fHasTexture = false;
			
			context->bindUniforms(&uniforms, sizeof(uniforms));
			context->bindGeometry((const float*) (resourceData + entry.offset), entry.numVertices, 
				(const int*)(resourceData + entry.offset + (entry.numVertices * kAttrsPerVertex 
				* sizeof(float))), entry.numIndices);
			context->submitDrawCommand();
		}

		int startInstructions = __builtin_nyuzi_read_control_reg(6);
		context->finish();
		printf("rendered frame in %d instructions\n", __builtin_nyuzi_read_control_reg(6) 
			- startInstructions);
		
		while (true)
			;
	}
	
	return 0;
}


