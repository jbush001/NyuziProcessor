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

#include <stdint.h>
#include "Surface.h"

namespace librender
{

const int kMaxMipLevels = 8;

class Texture
{
public:
    Texture();
    Texture(const Texture&) = delete;
    Texture& operator=(const Texture&) = delete;

    // Set the source raster data for a mip level.
    // This does not take ownership of the surfaces and will not free them.
    // mipLevel 0 must be set before higher levels. Calling this with miplevel
    // 0 after setting other levels will clear the other levels.
    void setMipSurface(int mipLevel, const Surface *surface);

    // Read up to 16 pixel values
    // @param u Horizontal coordinates, each is 0.0-1.0
    // @param v Vertical coordinates, 0.0-1.0
    // @param mask each bit corresponds to a vector lane. A 1 indicates the pixel
    //    should be fetched, a 0 it should be ignored.
    // @param This is an array that points to four vectors. The first vector is red,
    //    followed by blue, green, and alpha. Each lane of the vector corresponds to
    //    a lane in the coordinate vectors.
    void readPixels(vecf16_t u, vecf16_t v, vmask_t mask, vecf16_t *outChannels) const;

    // If enable is true, this will perform bilinear filtering to interpolate
    // values between pixels. If false, it will choose the nearest neighbor.
    void enableBilinearFiltering(bool enable)
    {
        fEnableBilinearFiltering = enable;
    }

private:
    const Surface *fMipSurfaces[kMaxMipLevels];
    bool fEnableBilinearFiltering = false;
    int fBaseMipBits = 0;
    int fMaxMipLevel = 0;
};

} // namespace librender
