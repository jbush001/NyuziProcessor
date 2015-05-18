// 
// Copyright 2015 Jeff Bush
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


#pragma once

#include "bspfile.h"
#include <Texture.h>
#include <RenderBuffer.h>
#include <stdio.h>

struct RenderLeaf
{
	librender::RenderBuffer vertexBuffer;
	librender::RenderBuffer indexBuffer;
};
	
struct RenderBspNode
{
	float normal[3];
	float distance;
	RenderBspNode *frontChild;
	RenderBspNode *backChild;
	int pvsIndex;
};

class PakFile
{
public:
	bool open(const char *filename);
	void readBsp(const char *lumpname);
	librender::Texture *getTexture()
	{
		return fAtlasTexture;
	}

	void dumpDirectory() const;
	void getTextureLocation(int id, float &left, float &bottom, float &width, float &height) const;
	void getLeaf(int index, const librender::RenderBuffer **vertexBuffer, 
		const librender::RenderBuffer **indexBuffer) const; 
	
private:
	struct FileHeader
	{
		char id[4];
		uint32_t dirOffset;
		uint32_t dirSize;
	};

	struct FileTableEntry
	{
		char name[56];
		uint32_t offset;
		uint32_t size;
	};

	struct AtlasEntry
	{
		float left;
		float bottom;
		float width;
		float height;
		int pixelWidth;
		int pixelHeight;
	};

	void *readFile(const char *filename) const;
	void loadTextureAtlas(const dheader_t *bspHeader, const uint8_t *data);
	void loadBspLeaves(const dheader_t *bspHeader, const uint8_t *data);
	void loadBspNodes(const dheader_t *bspHeader, const uint8_t *data);
	void loadBspModels(const dheader_t *bspHeader, const uint8_t *data);

	FileTableEntry *fDirectory;
	int fNumDirEntries;
	librender::Texture *fAtlasTexture;
	AtlasEntry *fAtlasEntries;
	RenderLeaf *fRenderLeaves;
	int fNumRenderLeaves;
	int fNumTextures;
	FILE *fFile;
};

