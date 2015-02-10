// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 

//
// Validates Z buffering by rendering two inter-penetrating triangles.
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

static float kTriangleVertices[] = {
	// 1st triangle
	 0.0,  0.9, -5.0,     1.0, 0.0, 0.0, 1.0, 
	-0.9, -0.7, -1.0,     1.0, 0.0, 0.0, 1.0,  
	 0.9, -0.7, -10.0,    1.0, 0.0, 0.0, 1.0, 

	// 2nd triangle
 	 0.0, -0.9, -5.0,     0.0, 1.0, 0.0, 1.0,  
 	 0.9,  0.7, -1.0,     0.0, 1.0, 0.0, 1.0,  
 	-0.9,  0.7, -10.0,    0.0, 1.0, 0.0, 1.0,  
};

static int kTriangleIndices[] = { 0, 1, 2, 3, 4, 5 };

int main()
{
	RenderContext *context = new RenderContext();
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	Surface *depthBuffer = new Surface(kFbWidth, kFbHeight);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setDepthBuffer(depthBuffer);
	context->bindTarget(renderTarget);
	context->enableDepthBuffer(true);
	context->bindShader(new ColorVertexShader(), new ColorPixelShader());
	context->bindGeometry(kTriangleVertices, 6, kTriangleIndices, 6);
	context->submitDrawCommand();
	context->finish();
	return 0;
}
