//
// Copyright 2011-2015 Jeff Bush
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

#include <stdio.h>
#include <stdlib.h>
#include "SIMDMath.h"

namespace librender
{

//
// RenderBuffer is a wrapper for an array of geometric data like
// vertex attributes or indices.
//

class RenderBuffer
{
public:
    RenderBuffer()
        :	fData(0),
            fNumElements(0),
            fStride(0),
            fBaseStepPointers(static_cast<veci16_t*>(memalign(sizeof(vecu16_t), sizeof(vecu16_t))))
    {
    }

    RenderBuffer(const RenderBuffer &) = delete;

    RenderBuffer(const void *data, int numElements, int stride)
        :	fBaseStepPointers(static_cast<veci16_t*>(memalign(sizeof(vecu16_t), sizeof(vecu16_t))))
    {
        setData(data, numElements, stride);
    }

    ~RenderBuffer()
    {
        free(fBaseStepPointers);
    }

    RenderBuffer& operator=(const RenderBuffer&) = delete;

    // The RenderBuffer does not take ownership of the data or copy it into
    // a separate buffer.  The caller must ensure the memory remains around
    // as long as the RenderBuffer is active.
    // XXX should there be a concept of owned and not-owned data like Surface?
    void setData(const void *data, int numElements, int stride)
    {
        fData = data;
        fNumElements = numElements;
        fStride = stride;

        const veci16_t kStepVector = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
        *fBaseStepPointers = kStepVector * fStride
                             + reinterpret_cast<int>(fData);
    }

    int getNumElements() const
    {
        return fNumElements;
    }

    int getStride() const
    {
        return fStride;
    }

    int getSize() const
    {
        return fNumElements * fStride;
    }

    const void *getData() const
    {
        return fData;
    }

    // Load up to 16 parameters with contiguous indices.
    // Given a packed array of the form a0b0 a0b1... a_1b_0 a_1b_1...
    // Return up to 16 elements packed in a vector: a_mb_n, a_mb_(n+1)...
    vecu16_t gatherElements(int baseIndex, int paramNum, vmask_t mask) const
    {
        const veci16_t ptrVec = *fBaseStepPointers + baseIndex * fStride
                                + paramNum * kElementSize;
        return __builtin_nyuzi_gather_loadf_masked(ptrVec, mask);
    }

    // Load up to 16 parameters with arbitrary indices.
    vecu16_t gatherElements(veci16_t indices, int paramNum, vmask_t mask) const
    {
        const veci16_t ptrVec = indices * fStride + paramNum * kElementSize
                                + reinterpret_cast<int>(fData);

        return __builtin_nyuzi_gather_loadf_masked(ptrVec, mask);
    }

private:
    const int kElementSize = 4;

    const void *fData;
    int fNumElements;
    int fStride;

    veci16_t *fBaseStepPointers;
};

} // namespace librender
