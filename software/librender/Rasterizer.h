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

#ifndef __RASTERIZER_H
#define __RASTERIZER_H

#include <stdint.h>
#include "ShaderFiller.h"

namespace librender
{

// Triangles are wound counter-clockwise
void fillTriangle(ShaderFiller &filler,
	int left, int top,
	int x1, int y1, int x2, int y2, int x3, int y3, 
	int clipRight, int clipBottom);

}

#endif
