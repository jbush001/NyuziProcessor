// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 


#include <stdio.h>
#include <RenderContext.h>
#include <Surface.h>
#include "TextureShader.h"
#include "block_device.h"
#include "schedule.h"


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

char *readResourceFile()
{
	char tmp[BLOCK_SIZE];
	unsigned int fileSize;
	char *resourceData;

	// Read the first block to determine how large the rest of the file is.
	read_block_device(0, tmp);
	fileSize = ((FileHeader*) tmp)->fileSize;

	printf("reading resource file, %d bytes\n", fileSize);
	
	resourceData = (char*) malloc(fileSize + BLOCK_SIZE);
	memcpy(resourceData, tmp, BLOCK_SIZE);
	for (int i = 1, len=(fileSize + BLOCK_SIZE - 1) / BLOCK_SIZE; i < len; i++)
		read_block_device(i * BLOCK_SIZE, resourceData + i * BLOCK_SIZE);

	return resourceData;
}

// All threads start execution here.
int main()
{
	if (__builtin_nyuzi_read_control_reg(0) != 0)
		workerThread();
	
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
	Surface *depthBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setDepthBuffer(depthBuffer);
	context->bindTarget(renderTarget);
	context->enableDepthBuffer(true);
	context->bindShader(new TextureVertexShader(), new TexturePixelShader());
	context->setClearColor(0.52, 0.80, 0.98);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);

	TextureUniforms uniforms;
	uniforms.fLightDirection = Vec3(-1, -0.5, 1).normalized();
	uniforms.fDirectional = 0.3f;		
	uniforms.fAmbient = 0.7f;
	float theta = 0.0;

	// Start worker threads
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);

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


