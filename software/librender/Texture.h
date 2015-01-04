// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


#ifndef __TEXTURE_SAMPLER_H
#define __TEXTURE_SAMPLER_H

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

#endif
