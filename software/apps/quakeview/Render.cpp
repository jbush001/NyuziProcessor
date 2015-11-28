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

#include "Render.h"

using namespace librender;

namespace
{

RenderBspNode *gBspRoot;
const uint8_t *gPvsList;
RenderBspNode *gLeaves;
int gNumLeaves;
Texture *gTextureAtlasTexture;
Texture *gLightmapAtlasTexture;
int gFrame;
const float kAtlasDebugVertices[] = {
	// Position        Texture Atlas Pos    Tex pos    Lightmap pos
	-1.0,  1.0, -1.0,  0.0, 0.0, 1.0, 1.0,  0.0, 1.0,  0.0, 1.0,
	-1.0, -1.0, -1.0,  0.0, 0.0, 1.0, 1.0,  0.0, 0.0,  0.0, 0.0,
	 1.0, -1.0, -1.0,  0.0, 0.0, 1.0, 1.0,  1.0, 0.0,  1.0, 0.0,
	 1.0,  1.0, -1.0,  0.0, 0.0, 1.0, 1.0,  1.0, 1.0,  1.0, 1.0
};

const int kAtlasDebugIndices[] = { 0, 1, 2, 2, 3, 0 };
const RenderBuffer kAtlasDebugVerticesRb(kAtlasDebugVertices, 4, 11 * sizeof(float));
const RenderBuffer kAtlasDebugIndicesRb(kAtlasDebugIndices, 6, sizeof(int));

RenderBspNode *findNode(RenderBspNode *head, float x, float y, float z)
{
	RenderBspNode *node = head;
	do
	{
		if (node->pointInFront(x, y, z))
			node = node->frontChild;
		else
			node = node->backChild;
	}
	while (node->frontChild);

	return node;
}

void markAllAncestors(RenderBspNode *node, int markNumber)
{
	while (node && node->markNumber != markNumber)
	{
		node->markNumber = markNumber;
		node = node->parent;
	}
}

void markLeaves(RenderBspNode *leafNodes, const uint8_t *pvsList, int index, int numLeaves, int markNumber)
{
	const uint8_t *pvs = pvsList + index;
	int currentLeaf = 1;
	while (currentLeaf < numLeaves)
	{
		if (*pvs == 0)
		{
			// Skip
			currentLeaf += pvs[1] * 8;
			pvs += 2;
			continue;
		}

		// XXX currentLeaf < numLeaves prevents a crash. I think I'm actually
		// running past the end of the PVS array.
		for (int mask = 1; mask <= 0x80 && currentLeaf < numLeaves; mask <<= 1)
		{
			if (*pvs & mask)
				markAllAncestors(leafNodes + currentLeaf, markNumber);

			currentLeaf++;
		}

		pvs++;
	}
}

// Render from front to back to take advantage of early-Z rejection
void renderRecursive(RenderContext *context, const RenderBspNode *node, const Vec3 &camera, int markNumber)
{
	if (!node->frontChild)
	{
		// Leaf node
		context->bindVertexAttrs(&node->vertexBuffer);
		context->drawElements(&node->indexBuffer);
	}
	else if (node->pointInFront(camera[0], camera[1], camera[2]))
	{
		if (node->frontChild->markNumber == markNumber)
			renderRecursive(context, node->frontChild, camera, markNumber);

		if (node->backChild->markNumber == markNumber)
			renderRecursive(context, node->backChild, camera, markNumber);
	}
	else
	{
		if (node->backChild->markNumber == markNumber)
			renderRecursive(context, node->backChild, camera, markNumber);

		if (node->frontChild->markNumber == markNumber)
			renderRecursive(context, node->frontChild, camera, markNumber);
	}
}

}

void setBspData(RenderBspNode *root, const uint8_t *pvsList, RenderBspNode *leaves, int numLeaves,
	Texture *atlasTexture, librender::Texture *lightmapAtlas)
{
	gBspRoot = root;
	gPvsList = pvsList;
	gLeaves = leaves;
	gNumLeaves = numLeaves;
	gTextureAtlasTexture = atlasTexture;
	gLightmapAtlasTexture = lightmapAtlas;
}

void renderScene(RenderContext *context, Vec3 cameraPos)
{
	context->bindTexture(0, gTextureAtlasTexture);
	context->bindTexture(1, gLightmapAtlasTexture);
	RenderBspNode *currentNode = findNode(gBspRoot, cameraPos[0], cameraPos[1], cameraPos[2]);
	markLeaves(gLeaves, gPvsList, currentNode->pvsIndex, gNumLeaves, gFrame);
	renderRecursive(context, gBspRoot, cameraPos, gFrame);
	gFrame++;
}

void renderTextureAtlas(RenderContext *context)
{
	context->bindTexture(0, gTextureAtlasTexture);
	context->bindTexture(1, gLightmapAtlasTexture);
	context->bindVertexAttrs(&kAtlasDebugVerticesRb);
	context->drawElements(&kAtlasDebugIndicesRb);
}


