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

// Data structures based on bspfile.h from quake sources

namespace Pak
{

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

struct DirEntry
{
	uint32_t offset;
	uint32_t size;
};

struct BspHeader
{
	uint32_t version;
	DirEntry entities;
	DirEntry planes;
	DirEntry miptex;
	DirEntry vertices;
	DirEntry vislist;
	DirEntry nodes;
	DirEntry texinfo;
	DirEntry faces;
	DirEntry lightmaps;
	DirEntry clipnodes;
	DirEntry leaves;
	DirEntry lface;
	DirEntry edges;
	DirEntry ledges;
	DirEntry models;
};

struct MipHeader
{
	uint32_t numTextures;
	uint32_t offsets[1];	// numTextures
};

const int kNumMipLevels = 4;

struct MipTexture
{
	char name[16];
	uint32_t width;
	uint32_t height;
	uint32_t mipLevelOffset[kNumMipLevels];
};

// texinfo_t
struct TextureInfo
{
	float vecs[2][4];
	int32_t miptex;
	int32_t flags;
};

// dleaf_t 
struct BspLeaf
{
	uint32_t type;
	uint32_t visibilityListBegin;
	int16_t mins[3];
	int16_t maxs[3];
	uint16_t firstFace;
	uint16_t numFaces;
	uint8_t sounds[4];
};

// dface_t
struct Face
{
	uint16_t planeId;
	uint16_t side;
	uint32_t firstEdge;
	uint16_t numEdges;
	uint16_t texinfoId;
	uint8_t styles[4];
	uint32_t lightmap;
};

// dedge_t
struct Edge
{
	uint16_t vertex[2];
};

// dvertex_t
struct Vertex
{
	float coord[3];
};

}
