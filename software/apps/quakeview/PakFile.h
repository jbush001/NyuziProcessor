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

#include "PakStructs.h"
#include <Texture.h>
#include <RenderBuffer.h>
#include <stdio.h>

struct BspNode
{
	
	
	
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
	struct AtlasEntry
	{
		float left;
		float bottom;
		float width;
		float height;
		int pixelWidth;
		int pixelHeight;
	};

	struct RenderLeaf
	{
		librender::RenderBuffer vertexBuffer;
		librender::RenderBuffer indexBuffer;
	};

	void *readFile(const char *filename) const;
	void loadTextureAtlas(const Pak::BspHeader *header, const uint8_t *data);
	void loadBspLeaves(const Pak::BspHeader *bspHeader, const uint8_t *data);

	Pak::FileTableEntry *fDirectory;
	int fNumDirEntries;
	librender::Texture *fAtlasTexture;
	AtlasEntry *fAtlasEntries;
	RenderLeaf *fRenderLeaves;
	int fNumRenderLeaves;
	int fNumTextures;
	FILE *fFile;
};

