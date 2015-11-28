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

//
// Quake .PAK file structures
//

const int kBspVersion = 29;
const int kNumMipLevels = 4;

struct pakheader_t
{
	char id[4];
	uint32_t dirOffset;
	uint32_t dirSize;
};

struct pakfile_t
{
	char name[56];
	uint32_t offset;
	uint32_t size;
};

struct lump_t
{
	uint32_t offset;
	uint32_t length;
};

struct bspheader_t
{
	uint32_t version;
	lump_t entities;
	lump_t planes;
	lump_t textures;
	lump_t vertices;
	lump_t visibility;
	lump_t nodes;
	lump_t texinfo;
	lump_t faces;
	lump_t lighting;
	lump_t clipnodes;
	lump_t leaves;
	lump_t marksurfaces;
	lump_t edges;
	lump_t surfedges;
	lump_t models;
};

struct miptex_t
{
	char name[16];
	uint32_t width;
	uint32_t height;
	uint32_t offsets[kNumMipLevels];
};

struct miptex_lump_t
{
	int32_t numTextures;
	int32_t offset[1];
};

struct vertex_t
{
	float coord[3];
};

struct plane_t
{
	float normal[3];
	float distance;
	int32_t type;
};

struct bspnode_t
{
	int32_t plane;
	int16_t children[2];
	int16_t min[3];
	int16_t max[3];
	uint16_t first_face;
	uint16_t num_faces;
};

struct texture_info_t
{
	float uVector[4];
	float vVector[4];
	int32_t miptex;
	int32_t flags;
};

struct edge_t
{
	uint16_t startVertex;
	uint16_t endVertex;
};

struct face_t
{
	uint16_t plane;
	uint16_t side;
	int32_t firstEdge;
	int16_t numEdges;
	int16_t texture;
	int8_t lightStyles[4];
	int32_t lightOffset;
};

struct leaf_t
{
	int32_t contents;
	int32_t pvsOffset;
	int16_t mins[3];
	int16_t maxs[3];
	uint16_t firstMarkSurface;
	uint16_t numMarkSurfaces;
	uint8_t ambientSound[4];
};











