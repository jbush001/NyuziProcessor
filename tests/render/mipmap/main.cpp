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


#include <schedule.h>
#include <stdlib.h>
#include <math.h>
#include <Matrix.h>
#include <Rasterizer.h>
#include <RenderTarget.h>
#include <TextureSampler.h>
#include <RenderContext.h>
#include "TextureShader.h"

using namespace render;

const int kFbWidth = 640;
const int kFbHeight = 480;

static float kTriangleVertices[] = {
	-0.9, -0.9, 9.0,  0.0, 0.0,
	-0.9, 0.9, 1.0,    0.0, 1.0,
	0.9, 0.9, 1.0,     1.0, 1.0,
	0.9, -0.9, 9.0,   1.0, 0.0,
};

static int kTriangleIndices[] = { 0, 1, 2, 2, 3, 0 };

void *operator new(size_t size, void *p)
{
	return p;
}
	
void makeMipMaps(TextureSampler *sampler)
{
	const unsigned int kColors[] = {
		0xff0000ff,	// Red
		0xff00ff00,	// Blue
		0xffff0000, // Green
		0xff00ffff, // Yellow 
	};

	for (int i = 0; i < 4; i++)
	{
		int mipSize = 512 >> i;
		Surface *mipSurface = new (memalign(64, sizeof(Surface))) Surface(mipSize, mipSize);
		unsigned int *bits = static_cast<unsigned int*>(mipSurface->lockBits());
		unsigned int color = kColors[i];
		for (int y = 0; y < mipSize; y++)
		{
			for (int x = 0; x < mipSize; x++)
			{
				if (((x ^ y) >> (5 - i)) & 1)
					bits[y * mipSize + x] = 0;
				else
					bits[y * mipSize + x] = color;
			}
		}
		
		sampler->bind(mipSurface, i);
		mipSize /= 2;
	}
}	
	
int main()
{
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	renderTarget->setColorBuffer(colorBuffer);
	RenderContext *context = new RenderContext(renderTarget);
	VertexShader *vertexShader = new (memalign(64, sizeof(TextureVertexShader))) TextureVertexShader();
	PixelShader *pixelShader = new TexturePixelShader(renderTarget);
	context->bindShader(vertexShader, pixelShader);

	TextureUniforms *uniforms = new TextureUniforms;
	uniforms->fTexture = new TextureSampler();
	context->bindUniforms(uniforms);
	uniforms->fTexture->setEnableBilinearFiltering(true);
	makeMipMaps(uniforms->fTexture);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);

	context->bindGeometry(kTriangleVertices, 4, kTriangleIndices, 6);
	
	uniforms->fMVPMatrix = projectionMatrix;
	context->renderFrame();
	
	return 0;
}
