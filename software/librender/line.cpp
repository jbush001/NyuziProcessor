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

// Clip masks
const unsigned int kBottom = 1;
const unsigned int kTop = 2;
const unsigned int kLeft = 4;
const unsigned int kRight = 8;

inline int vert_clip(int x1, int y1, int x2, int y2, int x)
{
	return y1 + (x - x1) * (y2 - y1) / (x2 - x1);
}

inline int horz_clip(int x1, int y1, int x2, int y2, int y)
{
	return x1 + (y - y1) * (x2 - x1) / (y2 - y1);
}

inline unsigned int clipmask(int x, int y, int left, int top, int right, int bottom)
{
	unsigned mask = 0;

	if (x < left)
		mask |= kLeft;
	else if (x > right)
		mask |= kRight;

	if (y < top)
		mask |= kTop;
	else if (y > bottom)
		mask |= kBottom;

	return mask;
}

void librender::drawLineClipped(Surface *dest, int x1, int y1, int x2, int y2, unsigned int color,
	int left, int top, int right, int bottom)
{
	int clippedX1 = x1;
	int clippedY1 = y1;
	int clippedX2 = x2;
	int clippedY2 = y2;

	unsigned point1mask = clipmask(clippedX1, clippedY1, left, top, right, bottom);
	unsigned point2mask = clipmask(clippedX2, clippedY2, left, top, right, bottom);

	bool rejected = false;
	while (point1mask != 0 || point2mask != 0) 
	{
		if ((point1mask & point2mask) != 0) 
		{
			rejected = true;
			break;
		}

		unsigned  mask = point1mask ? point1mask : point2mask;
		int x, y;
		if (mask & kBottom) 
		{
			y = bottom;
			x = horz_clip(clippedX1, clippedY1, clippedX2, clippedY2, y);
		} 
		else if (mask & kTop) 
		{
			y = top;
			x = horz_clip(clippedX1, clippedY1, clippedX2, clippedY2, y);
		} 
		else if (mask & kRight) 
		{
			x = right;
			y = vert_clip(clippedX1, clippedY1, clippedX2, clippedY2, x);
		} 
		else if (mask & kLeft) 
		{
			x = left;
			y = vert_clip(clippedX1, clippedY1, clippedX2, clippedY2, x);
		}

		if (point1mask) 
		{
			// Clip point 1
			point1mask = clipmask(x, y, left, top, right, bottom);
			clippedX1 = x;
			clippedY1 = y;
		} 
		else 
		{
			// Clip point 2
			point2mask = clipmask(x, y, left, top, right, bottom);
			clippedX2 = x;
			clippedY2 = y;
		}
	}
	
	if (!rejected)
		drawLine(dest, clippedX1, clippedY1, clippedX2, clippedY2, color);
}

void librender::drawLine(Surface *dest, int x1, int y1, int x2, int y2, unsigned int color)
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
	unsigned int *ptr = ((unsigned int*) dest->bits()) + x1 + y1 * dest->getWidth();
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
