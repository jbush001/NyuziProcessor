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
	void setMipSurface(int mipLevel, const Surface *surface);
	void readPixels(vecf16_t u, vecf16_t v, unsigned short mask, vecf16_t outChannels[4]) const;
	void enableBilinearFiltering(bool enable)
	{
		fEnableBilinearFiltering = enable;
	}

private:
	const Surface *fMipSurfaces[kMaxMipLevels];
	bool fEnableBilinearFiltering = false;
	int fBaseMipBits;
	int fMaxMipLevel = 0;
};

}
