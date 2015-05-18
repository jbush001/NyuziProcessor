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


#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include "PakFile.h"
#include "MeshBuilder.h"

using namespace Pak;
using namespace librender;


bool PakFile::open(const char *filename)
{
	fFile = fopen(filename, "rb");
	
	FileHeader header;
	if (fread(&header, sizeof(header), 1, fFile) != 1)
	{
		printf("PakFile::open: error reading file\n");
		return false;
	}
	
	if (::memcmp(header.id, "PACK", 4) != 0)
	{
		printf("PakFile::open: bad file type\n");
		return false;
	}

	fNumDirEntries = header.dirSize / sizeof(FileTableEntry);
	fDirectory = new FileTableEntry[fNumDirEntries];
	fseek(fFile, header.dirOffset, SEEK_SET);
	if (fread(fDirectory, header.dirSize, 1, fFile) != 1)
	{
		printf("PakFile::open: error reading directory\n");
		return false;
	}

	return true;
}

void *PakFile::readFile(const char *lumpname) const
{
	int fileIndex;
	
	for (fileIndex = 0; fileIndex < fNumDirEntries; fileIndex++)
	{
		if (::strcmp(fDirectory[fileIndex].name, lumpname) == 0)
			break;
	}

	if (fileIndex == fNumDirEntries)
		return nullptr;

	void *buf = malloc(fDirectory[fileIndex].size);
	fseek(fFile, fDirectory[fileIndex].offset, SEEK_SET);
	
	if (fread(buf, fDirectory[fileIndex].size, 1, fFile) != 1)
	{
		printf("PakFile::readFile: error reading\n");
		return nullptr;
	}
	
	return buf;
}

void PakFile::dumpDirectory() const
{
	for (int i = 0; i < fNumDirEntries; i++)
		printf("   %s %08x\n", fDirectory[i].name, fDirectory[i].size);
}

void PakFile::getTextureLocation(int id, float &left, float &bottom, float &width, float &height) const
{
	left = fAtlasEntries[id].left;
	bottom = fAtlasEntries[id].bottom;
	width = fAtlasEntries[id].width;
	height = fAtlasEntries[id].height;
}

void PakFile::getLeaf(int index, const librender::RenderBuffer **vertexBuffer, 
	const librender::RenderBuffer **indexBuffer) const
{
	*vertexBuffer = &fRenderLeaves[index].vertexBuffer;
	*indexBuffer = &fRenderLeaves[index].indexBuffer;
}


void PakFile::readBsp(const char *bspFilename)
{
	uint8_t *data = (uint8_t*) readFile(bspFilename);
	const BspHeader *bspHeader = (BspHeader*) data;

	if (bspHeader->version != 29)
	{
		printf("bad BSP version\n");
		exit(1);
	}

	loadTextureAtlas(bspHeader, data);
	loadBspLeaves(bspHeader, data);

	::free(data);
}

const int kAtlasSize = 768;
const int kGuardMargin = 4;

struct TexturePackingData 
{
	int textureId;
	unsigned int width;
	unsigned int height;
	const uint8_t *data[kNumMipLevels];
};

namespace 
{

int compareTexturePackingData(const void *a, const void *b)
{
	return ((const TexturePackingData*) b)->height - ((const TexturePackingData*) a)->height;
}

}

void PakFile::loadTextureAtlas(const BspHeader *bspHeader, const uint8_t *data)
{
	printf("PakFile::loadTextureAtlas\n");
	
	//
	// Read the palette.  Expand from 24bpp to 32bpp, our native format.
	//
	uint8_t *rawPalette = (uint8_t*) readFile("gfx/palette.lmp");
	uint32_t *palette = new uint32_t[256];
	for (int i = 0; i < 256; i++)
	{
		// Palette is R, G, B
		palette[i] = (rawPalette[i * 3 + 2] << 16) | (rawPalette[i * 3 + 1] << 8)
			| rawPalette[i * 3];
	}
	
	::free(rawPalette);

	//
	// Copy texture information into a temporary array
	//
	const MipHeader *mipHeader = (const MipHeader*)(data + bspHeader->miptex.offset);
	fNumTextures = mipHeader->numTextures;
	printf("%d textures\n", mipHeader->numTextures);

	TexturePackingData *texArray = new TexturePackingData[mipHeader->numTextures];
	for (int textureIdx = 0; textureIdx < mipHeader->numTextures; textureIdx++)
	{
		const MipTexture *texture = (const MipTexture*)(data + bspHeader->miptex.offset 
			+ mipHeader->offsets[textureIdx]);
		texArray[textureIdx].width = texture->width;
		texArray[textureIdx].height = texture->height;
		texArray[textureIdx].textureId = textureIdx;
		for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
		{
			texArray[textureIdx].data[mipLevel] = data + bspHeader->miptex.offset 
				+ mipHeader->offsets[textureIdx] + texture->mipLevelOffset[mipLevel];
		}
	}

	//
	// Sort textures by vertical size to pack better
	//
	qsort(texArray, mipHeader->numTextures, sizeof(TexturePackingData), 
		compareTexturePackingData);

	//
	// Create atlas mip surfaces
	//
	Surface *atlasSurfaces[kNumMipLevels];	// One for each mip level
	for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
	{
		atlasSurfaces[mipLevel] = new Surface(kAtlasSize >> mipLevel, kAtlasSize >> mipLevel);
		memset(atlasSurfaces[mipLevel]->bits(), 0, (kAtlasSize >> mipLevel) * (kAtlasSize >> mipLevel)
			* 4);
	}
	
	//
	// [Lightly] pack textures into the atlas. Horizontal bands are fixed height.
	//
	fAtlasEntries = new AtlasEntry[mipHeader->numTextures];
	int destX = 0;
	int destY = 0;
	int destRowHeight = texArray[0].height;
	for (int textureIdx = 0; textureIdx < mipHeader->numTextures; textureIdx++)
	{	
		if (destX + texArray[textureIdx].width > kAtlasSize)
		{
			// Start a new band
			destX = 0;
			destY += destRowHeight + kGuardMargin;
			destRowHeight = texArray[textureIdx].height;
		}

		// Save the coordinates of this texture in the atlas.
		int textureId = texArray[textureIdx].textureId;
		fAtlasEntries[textureId].left = float(destX) / (kAtlasSize - 1);
		fAtlasEntries[textureId].bottom = 1.0 - (float(destY + texArray[textureIdx].height - 1) / (kAtlasSize - 1));
		fAtlasEntries[textureId].width = float(texArray[textureIdx].width) / (kAtlasSize - 1);
		fAtlasEntries[textureId].height = float(texArray[textureIdx].height) / (kAtlasSize - 1);
		fAtlasEntries[textureId].pixelWidth = texArray[textureIdx].width;
		fAtlasEntries[textureId].pixelHeight = texArray[textureIdx].height;

		for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
		{
			int destStride = kAtlasSize >> mipLevel;
			int srcMipWidth = texArray[textureIdx].width >> mipLevel;
			int srcMipHeight = texArray[textureIdx].height >> mipLevel;
			assert(srcMipHeight <= destRowHeight);
			
			// Copy the data into the atlas
			uint32_t *dest = static_cast<uint32_t*>(atlasSurfaces[mipLevel]->bits())
				+ ((destY >> mipLevel) * destStride + (destX >> mipLevel));
			const uint8_t *src = static_cast<const uint8_t*>(texArray[textureIdx].data[mipLevel]);

			// Expand palette and copy into atlas surface
			for (int y = 0; y < srcMipHeight; y++)
			{
				for (int x = 0; x < srcMipWidth; x++)
					*dest++ = palette[*src++];
			
				dest += destStride - srcMipWidth;
			}
		}
		
		destX += texArray[textureIdx].width + kGuardMargin;
	}

	delete[] palette;

	fAtlasTexture = new Texture();
	for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
		fAtlasTexture->setMipSurface(mipLevel, atlasSurfaces[mipLevel]);

	delete[] texArray;
}

void PakFile::loadBspLeaves(const BspHeader *bspHeader, const uint8_t *data)
{
	const BspLeaf *leaves = (const BspLeaf*)(data + bspHeader->leaves.offset);
	fNumRenderLeaves = bspHeader->leaves.size / sizeof(BspLeaf);

	printf("PakFile::loadBspLeaves %d leaves\n", fNumRenderLeaves);

	fRenderLeaves = new RenderLeaf[fNumRenderLeaves];
	const uint16_t *faceList = (const uint16_t*)(data + bspHeader->lface.offset);
	const Face *faces = (const Face*)(data + bspHeader->faces.offset);
	const int32_t *edgeList = (const int32_t*)(data + bspHeader->ledges.offset);
	const Edge *edges = (const Edge*)(data + bspHeader->edges.offset);
	const Vertex *vertices = (const Vertex*)(data + bspHeader->vertices.offset);
	const TextureInfo *texInfos = (const TextureInfo*)(data + bspHeader->texinfo.offset);
	int totalTriangles = 0;
	
	for (int leafIndex = 0; leafIndex < fNumRenderLeaves; leafIndex++)
	{
		MeshBuilder builder(9);
		
		const BspLeaf &leaf = leaves[leafIndex];
#if 0
		printf("leaf %d (%d,%d,%d) - (%d,%d,%d)\n", leafIndex, leaf.mins[0], 
			leaf.mins[1], leaf.mins[2], leaf.maxs[0], leaf.maxs[1], leaf.maxs[2]);
#endif
			
		for (int faceListIndex = leaf.firstFace; 
			faceListIndex < leaf.firstFace + leaf.numFaces;
			faceListIndex++)
		{
			const Face &face = faces[faceList[faceListIndex]];
			const TextureInfo &textureInfo = texInfos[face.texinfoId];
			float left = fAtlasEntries[textureInfo.miptex].left;
			float bottom = fAtlasEntries[textureInfo.miptex].bottom;
			float width = fAtlasEntries[textureInfo.miptex].width;
			float height = fAtlasEntries[textureInfo.miptex].height;
			
			float polyAttrs[9] = { 0, 0, 0, left, bottom, width, height, 0, 0 };

			for (int edgeListIndex = face.firstEdge; 
				edgeListIndex < face.firstEdge + face.numEdges;
				edgeListIndex++)
			{
				int16_t edgeIndex = edgeList[edgeListIndex];
				int vertexIndex;
				if (edgeIndex < 0)
				{
					// Reverse direction
					edgeIndex = -edgeIndex;
					const Edge &edge = edges[edgeIndex];
					vertexIndex = edge.vertex[1];
				}
				else
				{
					const Edge &edge = edges[edgeIndex];
					vertexIndex = edge.vertex[0];
				}

				// Copy coordinate
				for (int i = 0; i < 3; i++)
					polyAttrs[i] = vertices[vertexIndex].coord[i];

				// Compute texture coordinates
				// U
				polyAttrs[7] = (polyAttrs[0] * textureInfo.vecs[0][0] + polyAttrs[1] * textureInfo.vecs[0][1]
					+ polyAttrs[2] * textureInfo.vecs[0][2] + textureInfo.vecs[0][3]) 
					/ fAtlasEntries[textureInfo.miptex].pixelWidth;
				
				// V
				polyAttrs[8] = -(polyAttrs[0] * textureInfo.vecs[1][0] + polyAttrs[1] * textureInfo.vecs[1][1]
					+ polyAttrs[2] * textureInfo.vecs[1][2] + textureInfo.vecs[1][3])
					/ fAtlasEntries[textureInfo.miptex].pixelHeight;

				builder.addPolyPoint(polyAttrs);
			}
			
			totalTriangles += face.numEdges - 2;
			
			builder.finishPoly();
		}
		
		builder.finish(fRenderLeaves[leafIndex].vertexBuffer, fRenderLeaves[leafIndex].indexBuffer);
	}
	
	printf("total triangles %d\n", totalTriangles);
}





