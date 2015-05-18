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

	printf("reading %s, %d  bytes\n", lumpname, fDirectory[fileIndex].size);

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

RenderBspNode *PakFile::getLeafBspNode(int index)
{
	return &fBspRoot[index + fNumInteriorNodes];
}

void PakFile::readBsp(const char *bspFilename)
{
	uint8_t *data = (uint8_t*) readFile(bspFilename);
	const dheader_t *bspHeader = (dheader_t*) data;

	if (bspHeader->version != BSPVERSION)
	{
		printf("bad BSP version\n");
		exit(1);
	}

	loadTextureAtlas(bspHeader, data);
	loadBspLeaves(bspHeader, data);
	loadBspNodes(bspHeader, data);

	int pvsLen = bspHeader->lumps[LUMP_VISIBILITY].filelen;
	fPvsData = (unsigned char*) malloc(pvsLen);
	::memcpy(fPvsData, data + bspHeader->lumps[LUMP_VISIBILITY].fileofs, pvsLen);
	printf("PVS list is %d bytes\n", pvsLen);

	::free(data);
}

const int kAtlasSize = 768;
const int kGuardMargin = 4;

struct TexturePackingData 
{
	int textureId;
	unsigned int width;
	unsigned int height;
	const uint8_t *data[MIPLEVELS];
};

namespace 
{

int compareTexturePackingData(const void *a, const void *b)
{
	return ((const TexturePackingData*) b)->height - ((const TexturePackingData*) a)->height;
}

}

void PakFile::loadTextureAtlas(const dheader_t *bspHeader, const uint8_t *data)
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
	const dmiptexlump_t *mipHeader = (const dmiptexlump_t*)(data + bspHeader->lumps[LUMP_TEXTURES].fileofs);
	fNumTextures = mipHeader->nummiptex;
	printf("%d textures\n", mipHeader->nummiptex);

	TexturePackingData *texArray = new TexturePackingData[mipHeader->nummiptex];
	for (int textureIdx = 0; textureIdx < mipHeader->nummiptex; textureIdx++)
	{
		const miptex_t *texture = (const miptex_t*)(data + bspHeader->lumps[LUMP_TEXTURES].fileofs 
			+ mipHeader->dataofs[textureIdx]);
		texArray[textureIdx].width = texture->width;
		texArray[textureIdx].height = texture->height;
		texArray[textureIdx].textureId = textureIdx;
		for (int mipLevel = 0; mipLevel < MIPLEVELS; mipLevel++)
		{
			texArray[textureIdx].data[mipLevel] = data + bspHeader->lumps[LUMP_TEXTURES].fileofs 
				+ mipHeader->dataofs[textureIdx] + texture->offsets[mipLevel];
		}
	}

	//
	// Sort textures by vertical size to pack better
	//
	qsort(texArray, mipHeader->nummiptex, sizeof(TexturePackingData), 
		compareTexturePackingData);

	//
	// Create atlas mip surfaces
	//
	Surface *atlasSurfaces[MIPLEVELS];	// One for each mip level
	for (int mipLevel = 0; mipLevel < MIPLEVELS; mipLevel++)
	{
		atlasSurfaces[mipLevel] = new Surface(kAtlasSize >> mipLevel, kAtlasSize >> mipLevel);
		memset(atlasSurfaces[mipLevel]->bits(), 0, (kAtlasSize >> mipLevel) * (kAtlasSize >> mipLevel)
			* 4);
	}
	
	//
	// [Lightly] pack textures into the atlas. Horizontal bands are fixed height.
	//
	fAtlasEntries = new AtlasEntry[mipHeader->nummiptex];
	int destX = 0;
	int destY = 0;
	int destRowHeight = texArray[0].height;
	for (int textureIdx = 0; textureIdx < mipHeader->nummiptex; textureIdx++)
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

		for (int mipLevel = 0; mipLevel < MIPLEVELS; mipLevel++)
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
	fAtlasTexture->enableBilinearFiltering(true);
	for (int mipLevel = 0; mipLevel < MIPLEVELS; mipLevel++)
		fAtlasTexture->setMipSurface(mipLevel, atlasSurfaces[mipLevel]);

	delete[] texArray;
}

void PakFile::loadBspLeaves(const dheader_t *bspHeader, const uint8_t *data)
{
	const dleaf_t *leaves = (const dleaf_t*)(data + bspHeader->lumps[LUMP_LEAFS].fileofs);
	fNumRenderLeaves = bspHeader->lumps[LUMP_LEAFS].filelen / sizeof(dleaf_t);

	printf("PakFile::loadBspLeaves %d leaves\n", fNumRenderLeaves);

	fRenderLeaves = new RenderLeaf[fNumRenderLeaves];
	const uint16_t *faceList = (const uint16_t*)(data + bspHeader->lumps[LUMP_MARKSURFACES].fileofs);
	const dface_t *faces = (const dface_t*)(data + bspHeader->lumps[LUMP_FACES].fileofs);
	const int32_t *edgeList = (const int32_t*)(data + bspHeader->lumps[LUMP_SURFEDGES].fileofs);
	const dedge_t *edges = (const dedge_t*)(data + bspHeader->lumps[LUMP_EDGES].fileofs);
	const dvertex_t *vertices = (const dvertex_t*)(data + bspHeader->lumps[LUMP_VERTEXES].fileofs);
	const texinfo_t *texInfos = (const texinfo_t*)(data + bspHeader->lumps[LUMP_TEXINFO].fileofs);
	int totalTriangles = 0;
	
	for (int leafIndex = 0; leafIndex < fNumRenderLeaves; leafIndex++)
	{
		MeshBuilder builder(9);
		
		const dleaf_t &leaf = leaves[leafIndex];
#if 0
		printf("leaf %d (%d,%d,%d) - (%d,%d,%d)\n", leafIndex, leaf.mins[0], 
			leaf.mins[1], leaf.mins[2], leaf.maxs[0], leaf.maxs[1], leaf.maxs[2]);
#endif
			
		for (int faceListIndex = leaf.firstmarksurface; 
			faceListIndex < leaf.firstmarksurface + leaf.nummarksurfaces;
			faceListIndex++)
		{
			const dface_t &face = faces[faceList[faceListIndex]];
			const texinfo_t &textureInfo = texInfos[face.texinfo];
			float left = fAtlasEntries[textureInfo.miptex].left;
			float bottom = fAtlasEntries[textureInfo.miptex].bottom;
			float width = fAtlasEntries[textureInfo.miptex].width;
			float height = fAtlasEntries[textureInfo.miptex].height;
			
			float polyAttrs[9] = { 0, 0, 0, left, bottom, width, height, 0, 0 };

			for (int edgeListIndex = face.firstedge; 
				edgeListIndex < face.firstedge + face.numedges;
				edgeListIndex++)
			{
				int16_t edgeIndex = edgeList[edgeListIndex];
				int vertexIndex;
				if (edgeIndex < 0)
				{
					// Reverse direction
					vertexIndex = edges[-edgeIndex].v[1];
				}
				else
				{
					vertexIndex = edges[edgeIndex].v[0];
				}

				// Copy coordinate
				for (int i = 0; i < 3; i++)
					polyAttrs[i] = vertices[vertexIndex].point[i];

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
			
			totalTriangles += face.numedges - 2;
			
			builder.finishPoly();
		}
		
		builder.finish(fRenderLeaves[leafIndex].vertexBuffer, fRenderLeaves[leafIndex].indexBuffer);
	}
	
	printf("total triangles %d\n", totalTriangles);
}

void PakFile::loadBspNodes(const dheader_t *bspHeader, const uint8_t *data)
{
	const dnode_t *nodes = (const dnode_t*)(data + bspHeader->lumps[LUMP_NODES].fileofs);
	const dplane_t *planes = (const dplane_t*)(data + bspHeader->lumps[LUMP_PLANES].fileofs);
	const dleaf_t *leaves = (const dleaf_t*)(data + bspHeader->lumps[LUMP_LEAFS].fileofs);
	fNumInteriorNodes = bspHeader->lumps[LUMP_NODES].filelen / sizeof(dnode_t);
	int numLeaves = bspHeader->lumps[LUMP_LEAFS].filelen / sizeof(dleaf_t);
	
	RenderBspNode *renderNodes = new RenderBspNode[fNumInteriorNodes + numLeaves];
	printf("creating %d render nodes\n", fNumInteriorNodes + numLeaves);
	
	for (int i = 0; i < fNumInteriorNodes; i++)
	{
		const dplane_t &nodePlane = planes[nodes[i].planenum];
		for (int j = 0; j < 3; j++)
			renderNodes[i].normal[j] = nodePlane.normal[j];
		
		renderNodes[i].distance = nodePlane.dist;
		
		if (nodes[i].children[0] & 0x8000)
			renderNodes[i].frontChild = &renderNodes[~nodes[i].children[0] + fNumInteriorNodes];
		else
			renderNodes[i].frontChild = &renderNodes[nodes[i].children[0]];

		if (nodes[i].children[1] & 0x8000)
			renderNodes[i].backChild = &renderNodes[~nodes[i].children[1] + fNumInteriorNodes];
		else
			renderNodes[i].backChild = &renderNodes[nodes[i].children[1]];
		
		renderNodes[i].frontChild->parent = &renderNodes[i];
		renderNodes[i].backChild->parent = &renderNodes[i];
		renderNodes[i].leaf = nullptr;
	}
		
	for (int i = 0; i < numLeaves; i++)
	{
		renderNodes[i + fNumInteriorNodes].frontChild = nullptr;
		renderNodes[i + fNumInteriorNodes].backChild = nullptr;
		renderNodes[i + fNumInteriorNodes].pvsIndex = leaves[i].visofs;
		renderNodes[i + fNumInteriorNodes].leafIndex = i;
		renderNodes[i + fNumInteriorNodes].leaf = &fRenderLeaves[i];
	}
	
	fBspRoot = renderNodes;
}






