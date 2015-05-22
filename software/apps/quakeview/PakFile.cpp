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
	
	pakheader_t header;
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

	fNumDirEntries = header.dirSize / sizeof(pakfile_t);
	fDirectory = new pakfile_t[fNumDirEntries];
	fseek(fFile, header.dirOffset, SEEK_SET);
	if (fread(fDirectory, header.dirSize, 1, fFile) != 1)
	{
		printf("PakFile::open: error reading directory\n");
		return false;
	}

	return true;
}

// Read a file archived in the PAK file into memory and return
// a pointer to the allocated buffer.
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
	{
		printf("   %s %08x %08x\n", fDirectory[i].name, fDirectory[i].offset, 
			fDirectory[i].size);
	}
}

void PakFile::readBspFile(const char *bspFilename)
{
	uint8_t *data = (uint8_t*) readFile(bspFilename);
	if (!data)
	{
		printf("Couldn't find BSP file");
		return;
	}
	
	const bspheader_t *bspHeader = (bspheader_t*) data;

	if (bspHeader->version != kBspVersion)
	{
		printf("bad BSP version\n");
		exit(1);
	}

	loadTextureAtlas(bspHeader, data);
	loadBspNodes(bspHeader, data);

	int pvsLen = bspHeader->visibility.length;
	fPvsData = (unsigned char*) malloc(pvsLen);
	::memcpy(fPvsData, data + bspHeader->visibility.offset, pvsLen);
	printf("PVS list is %d bytes\n", pvsLen);

// Need to parse this:
// {
// "classname" "info_player_start"
// "origin" "480 -352 88"
// "angle" "90"
// }

#if 0
	const char *entities = (const char*)(data + bspHeader->entities.offset);
	printf("%s\n", entities);
#endif

	::free(data);
}

const int kAtlasSize = 1024;

// This is the guart margin at the largest mip level. At every level it is divided by two.
// It's two pixels at the lowest mip level.
const int kGuardMargin = 16;	

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

void PakFile::loadTextureAtlas(const bspheader_t *bspHeader, const uint8_t *data)
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
	const miptex_lump_t *mipHeader = (const miptex_lump_t*)(data + bspHeader->textures.offset);
	fNumTextures = mipHeader->numTextures;
	printf("%d textures\n", mipHeader->numTextures);

	TexturePackingData *texArray = new TexturePackingData[mipHeader->numTextures];
	for (int textureIdx = 0; textureIdx < mipHeader->numTextures; textureIdx++)
	{
		const miptex_t *texture = (const miptex_t*)(data + bspHeader->textures.offset 
			+ mipHeader->offset[textureIdx]);
		texArray[textureIdx].width = texture->width;
		texArray[textureIdx].height = texture->height;
		texArray[textureIdx].textureId = textureIdx;
		for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
		{
			texArray[textureIdx].data[mipLevel] = data + bspHeader->textures.offset 
				+ mipHeader->offset[textureIdx] + texture->offsets[mipLevel];
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
		::memset(atlasSurfaces[mipLevel]->bits(), 0, (kAtlasSize >> mipLevel) * (kAtlasSize >> mipLevel)
			* 4);
	}
	
	//
	// [Lightly] pack textures into the atlas. Horizontal bands are fixed height.
	//
	fAtlasEntries = new AtlasEntry[mipHeader->numTextures];
	int destX = kGuardMargin;
	int destY = kGuardMargin;
	int destRowHeight = texArray[0].height;
	for (int textureIdx = 0; textureIdx < mipHeader->numTextures; textureIdx++)
	{	
		if (destX + texArray[textureIdx].width + kGuardMargin > kAtlasSize)
		{
			// Start a new band
			destX = kGuardMargin;
			destY += destRowHeight + kGuardMargin;
			destRowHeight = texArray[textureIdx].height;
			assert(destY + destRowHeight <= kAtlasSize);
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
					dest[y * destStride + x] = palette[src[y * srcMipWidth + x]];

				// Mirror the right edge to the left and vice versa to wrap properly
				// with bilinear filtering
				dest[y * destStride - 1] = palette[src[(y + 1) * srcMipWidth - 1]];
				dest[y * destStride + srcMipWidth] = palette[src[y * srcMipWidth]];
			}

			// Mirror top edge to bottom, etc. as above.
			for (int x = 0; x < srcMipWidth; x++)
			{
				dest[x - destStride] = palette[src[srcMipWidth * (srcMipHeight - 1) + x]];
				dest[x + destStride * srcMipHeight] = palette[src[x]];
			}
		}
		
		destX += texArray[textureIdx].width + kGuardMargin;
	}

	delete[] palette;

	fAtlasTexture = new Texture();
	fAtlasTexture->enableBilinearFiltering(true);
	for (int mipLevel = 0; mipLevel < kNumMipLevels; mipLevel++)
		fAtlasTexture->setMipSurface(mipLevel, atlasSurfaces[mipLevel]);

	delete[] texArray;
}

void PakFile::loadBspNodes(const bspheader_t *bspHeader, const uint8_t *data)
{
	const leaf_t *leaves = (const leaf_t*)(data + bspHeader->leaves.offset);
	const uint16_t *faceList = (const uint16_t*)(data + bspHeader->marksurfaces.offset);
	const face_t *faces = (const face_t*)(data + bspHeader->faces.offset);
	const int32_t *edgeList = (const int32_t*)(data + bspHeader->surfedges.offset);
	const edge_t *edges = (const edge_t*)(data + bspHeader->edges.offset);
	const vertex_t *vertices = (const vertex_t*)(data + bspHeader->vertices.offset);
	const texture_info_t *texInfos = (const texture_info_t*)(data + bspHeader->texinfo.offset);
	const bspnode_t *nodes = (const bspnode_t*)(data + bspHeader->nodes.offset);
	const plane_t *planes = (const plane_t*)(data + bspHeader->planes.offset);

	fNumBspLeaves = bspHeader->leaves.length / sizeof(leaf_t);
	fNumInteriorNodes = bspHeader->nodes.length / sizeof(bspnode_t);
	fBspNodes = new RenderBspNode[fNumInteriorNodes + fNumBspLeaves];
	
	// Initialize leaf nodes
	for (int leafIndex = 0; leafIndex < fNumBspLeaves; leafIndex++)
	{
		MeshBuilder builder(9);
		
		const leaf_t &leaf = leaves[leafIndex];
		for (int faceListIndex = leaf.firstMarkSurface; 
			faceListIndex < leaf.firstMarkSurface + leaf.numMarkSurfaces;
			faceListIndex++)
		{
			const face_t &face = faces[faceList[faceListIndex]];
			const texture_info_t &textureInfo = texInfos[face.texture];
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
					vertexIndex = edges[-edgeIndex].endVertex;
				}
				else
				{
					vertexIndex = edges[edgeIndex].startVertex;
				}

				// Copy coordinate
				for (int i = 0; i < 3; i++)
					polyAttrs[i] = vertices[vertexIndex].coord[i];

				// Compute texture coordinates
				// U
				polyAttrs[7] = (polyAttrs[0] * textureInfo.uVector[0] 
					+ polyAttrs[1] * textureInfo.uVector[1]
					+ polyAttrs[2] * textureInfo.uVector[2] 
					+ textureInfo.uVector[3]) 
					/ fAtlasEntries[textureInfo.miptex].pixelWidth;
				
				// V
				polyAttrs[8] = -(polyAttrs[0] * textureInfo.vVector[0] 
					+ polyAttrs[1] * textureInfo.vVector[1]
					+ polyAttrs[2] * textureInfo.vVector[2] 
					+ textureInfo.vVector[3])
					/ fAtlasEntries[textureInfo.miptex].pixelHeight;

				builder.addPolyPoint(polyAttrs);
			}
			
			builder.finishPoly();
		}
		
		builder.finish(fBspNodes[fNumInteriorNodes + leafIndex].vertexBuffer, 
			fBspNodes[fNumInteriorNodes + leafIndex].indexBuffer);
		fBspNodes[fNumInteriorNodes + leafIndex].pvsIndex = leaves[leafIndex].pvsOffset;
	}

	//
	// Initialize interior nodes
	//
	for (int i = 0; i < fNumInteriorNodes; i++)
	{
		const plane_t &nodePlane = planes[nodes[i].plane];
		for (int j = 0; j < 3; j++)
			fBspNodes[i].normal[j] = nodePlane.normal[j];
		
		fBspNodes[i].distance = nodePlane.distance;

		if (nodes[i].children[0] & 0x8000)
			fBspNodes[i].frontChild = &fBspNodes[~nodes[i].children[0] + fNumInteriorNodes];
		else
			fBspNodes[i].frontChild = &fBspNodes[nodes[i].children[0]];

		if (nodes[i].children[1] & 0x8000)
			fBspNodes[i].backChild = &fBspNodes[~nodes[i].children[1] + fNumInteriorNodes];
		else
			fBspNodes[i].backChild = &fBspNodes[nodes[i].children[1]];
		
		fBspNodes[i].frontChild->parent = &fBspNodes[i];
		fBspNodes[i].backChild->parent = &fBspNodes[i];
	}
}






