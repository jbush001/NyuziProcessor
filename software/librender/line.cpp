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

#include "line.h"

using namespace librender;

void drawLine(Surface *dest, int x1, int y1, int x2, int y2, unsigned int color)
{
	// Swap if necessary so we always draw top to bottom
	if (y1 > y2) 
	{
		int temp = y1;
		y1 = y2;
		y2 = temp;

		temp = x1;
		x1 = x2;
		x2 = temp;
	}

	int deltaY = (y2 - y1) + 1;
	int deltaX = x2 > x1 ? (x2 - x1) + 1 : (x1 - x2) + 1;
	int xDir = x2 > x1 ? 1 : -1;
	int error = 0;
	unsigned int *ptr = ((unsigned int*) dest->lockBits()) + x1 + y1 * dest->getWidth();
	int stride = dest->getWidth();

	if (deltaX == 0) 
	{
		// Vertical line
		for (int y = deltaY; y > 0; y--) 
		{
			*ptr = color;
			ptr += stride;
		}
	} 
	else if (deltaY == 0) 
	{
		// Horizontal line
		for (int x = deltaX; x > 0; x--) 
		{
			*ptr = color;
			ptr += xDir;
		}
	} 
	else if (deltaX > deltaY) 
	{
		// Diagonal with horizontal major axis
		int x = x1;
		for (;;) 
		{
			*ptr = color;
			error += deltaY;
			if (error > deltaX) 
			{
				ptr += stride;
				error -= deltaX;
			}

			ptr += xDir;
			if (x == x2)
				break;

			x += xDir;
		}
	} 
	else 
	{
		// Diagonal with vertical major axis
		for (int y = y1; y <= y2; y++) 
		{
			*ptr = color;
			error += deltaX;
			if (error > deltaY) 
			{
				ptr += xDir;
				error -= deltaY;
			}

			ptr += stride;
		}
	}
}
