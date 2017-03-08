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

#include "SIMDMath.h"

namespace librender
{

//
// 2D linear interpolator.
//

class LinearInterpolator
{
public:
    void init(float xGradient, float yGradient, float c00)
    {
        fXGradient = xGradient;
        fYGradient = yGradient;
        fC00 = c00;
    }

    // Return values of this parameter at 16 locations given by the vectors
    // x and y.
    inline vecf16_t getValuesAt(vecf16_t x, vecf16_t y) const
    {
        return x * fXGradient + y * fYGradient + fC00;
    }

private:
    float fXGradient;
    float fYGradient;
    float fC00;	// Value of C at 0, 0
};

} // namespace librender
