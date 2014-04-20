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

#include "Surface.h"

namespace render
{

class TextureSampler
{
public:
	TextureSampler();
	void bind(Surface *surface);
	void readPixels(vecf16 u, vecf16 v, unsigned short mask, vecf16 outChannels[4]) const;
	void setEnableBilinearFiltering(bool enabled)
	{
		fBilinearFilteringEnabled = enabled;
	}

private:
	Surface *fSurface;
	float fWidth;
	float fHeight;
	bool fBilinearFilteringEnabled;
};

}

#endif
