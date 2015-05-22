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

#include "pak.h"
#include <Texture.h>
#include <RenderBuffer.h>
#include <stdio.h>
#include "Render.h"
	
class PakFile
{
public:
	bool open(const char *filename);
	void readBspFile(const char *lumpname);
	librender::Texture *getTexture()
	{
		return fAtlasTexture;
	}

	void dumpDirectory() const;

	RenderBspNode *getBspTree()
	{
		return fBspNodes;	// First node is root
	}
	
	const uint8_t *getPvsList()
	{
		return fPvsData;
	}
	
	int getNumInteriorNodes() const
	{
		return fNumInteriorNodes;
	}
	
	int getNumLeaves() const
	{
		return fNumBspLeaves;
	}
	
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

	void *readFile(const char *filename) const;
	void loadTextureAtlas(const bspheader_t *bspHeader, const uint8_t *data);
	void loadBspNodes(const bspheader_t *bspHeader, const uint8_t *data);

	pakfile_t *fDirectory;
	int fNumDirEntries;
	librender::Texture *fAtlasTexture;
	AtlasEntry *fAtlasEntries;
	int fNumBspLeaves;
	int fNumTextures;
	FILE *fFile;
	RenderBspNode *fBspNodes;
	uint8_t *fPvsData;
	int fNumInteriorNodes;
};

