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

#include <RenderBuffer.h>

const int kMinAlloc = 32;

//
// Given convex polygons, specified a single vertex at a time, create
// RenderBuffers that contain vertex locations and triangle indices.
//

class MeshBuilder
{
public:
    MeshBuilder(int numAttributes);
    void addPolyPoint(const float attributes[]);
    void finishPoly();
    void finish(librender::RenderBuffer &vertexBuffer, librender::RenderBuffer &indexBuffer);

private:
    void appendIndex(int value);
    void appendVertex(float value);

    int fNumAttributes;
    int *fIndexVector = nullptr;
    int fNumIndices = 0;
    float *fVertexVector = nullptr;
    int fNumVertexAttrs = 0;
    int fPolyPointCount = 0;
    int fFirstPolyIndex = 0;
    int fPolyIndex1 = 0;
    int fPolyIndex2 = 0;
};
