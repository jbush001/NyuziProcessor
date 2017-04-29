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


#include <stdlib.h>
#include <stdio.h>
#include "MeshBuilder.h"

MeshBuilder::MeshBuilder(int numAttributes)
    : fNumAttributes(numAttributes)
{
}

void MeshBuilder::appendIndex(int value)
{
    if (fNumIndices == 0)
        fIndexVector = static_cast<int*>(malloc(sizeof(int) * kMinAlloc));
    else if (fNumIndices >= kMinAlloc && (fNumIndices & (fNumIndices - 1)) == 0) {
        int *newArray = static_cast<int*>(realloc(fIndexVector, fNumIndices
            * 2 * sizeof(int)));
        if (newArray == nullptr) {
            printf("out of memory\n");
            return;
        }

        fIndexVector = newArray;
    }

    fIndexVector[fNumIndices++] = value;
}

void MeshBuilder::appendVertex(float value)
{
    if (fNumVertexAttrs == 0)
        fVertexVector = static_cast<float*>(malloc(sizeof(float) * kMinAlloc));
    else if (fNumVertexAttrs >= kMinAlloc && (fNumVertexAttrs & (fNumVertexAttrs - 1)) == 0) {
        float *newArray = static_cast<float*>(realloc(fVertexVector, fNumVertexAttrs
            * 2 * sizeof(float)));
        if (newArray == nullptr) {
            printf("out of memory\n");
            return;
        }

        fVertexVector = newArray;
    }

    fVertexVector[fNumVertexAttrs++] = value;
}

void MeshBuilder::addPolyPoint(const float attributes[])
{
    int vertexIndex = fNumVertexAttrs / fNumAttributes;

    for (int i = 0; i < fNumAttributes; i++)
        appendVertex(attributes[i]);

    if (fPolyPointCount == 0)
        fFirstPolyIndex = vertexIndex;
    else
    {
        fPolyIndex1 = fPolyIndex2;
        fPolyIndex2 = vertexIndex;
    }

    if (++fPolyPointCount > 2)
    {
        // Add triangle.  The triangle is wound counterclockwise, although
        // the polygon is wound clockwise.
        appendIndex(fFirstPolyIndex);
        appendIndex(fPolyIndex2);
        appendIndex(fPolyIndex1);
    }
}

void MeshBuilder::finishPoly()
{
    fPolyPointCount = 0;
}

void MeshBuilder::finish(librender::RenderBuffer &vertexBuffer, librender::RenderBuffer &indexBuffer)
{
    vertexBuffer.setData(fVertexVector, fNumVertexAttrs / fNumAttributes,
                         sizeof(float) * fNumAttributes);
    indexBuffer.setData(fIndexVector, fNumIndices, sizeof(int));
}

