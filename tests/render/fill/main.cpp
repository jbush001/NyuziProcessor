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


//
// Fill the entire framebuffer with a solid color.
// Validates rasterizer viewport clipping and all
// rasterizer coverage cases
//

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include <Matrix.h>
#include <RenderTarget.h>
#include <RenderContext.h>
#include "ColorShader.h"

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;

static float kSquareVertices[] = {
	// 1st triangle
	-1.0,  1.0, -1.0,
	-1.0, -1.0, -1.0,
	 1.0, -1.0, -1.0,
	 1.0,  1.0, -1.0,
};

static int kSquareIndices[] = { 0, 1, 2, 2, 3, 0 };

// Ensure clipping works correctly by filling entire framebuffer
int main()
{
	RenderContext *context = new RenderContext();
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	renderTarget->setColorBuffer(colorBuffer);
	context->bindTarget(renderTarget);
	context->bindShader(new ColorVertexShader(), new ColorPixelShader());
	context->bindGeometry(kSquareVertices, 4, kSquareIndices, 6);
	context->submitDrawCommand();
	context->finish();
	return 0;
}
