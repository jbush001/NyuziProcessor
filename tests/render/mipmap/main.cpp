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
// Validate multiple level-of-detail textures by rendering a square
// that stretches far into the Z direction. Each mip level is a different
// color to show where the level changes.
//

#include <schedule.h>
#include <stdlib.h>
#include <math.h>
#include <Matrix.h>
#include <RenderTarget.h>
#include <Texture.h>
#include <RenderContext.h>
#include "TextureShader.h"

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;

static float kSquareVertices[] = {
	-3.0, -3.0, -25.0,  0.0, 0.0,
	-3.0, -3.0, -1.0,    0.0, 1.0,
	3.0,  -3.0, -1.0,     1.0, 1.0,
	3.0,  -3.0, -25.0,   1.0, 0.0,
};

static int kSquareIndices[] = { 0, 1, 2, 2, 3, 0 };
	
Texture *makeMipMaps()
{
	const unsigned int kColors[] = {
		0xff0000ff,	// Red
		0xff00ff00,	// Blue
		0xffff0000, // Green
		0xff00ffff, // Yellow 
	};
	
	Texture *texture = new Texture();
	for (int i = 0; i < 4; i++)
	{
		int mipSize = 512 >> i;
		Surface *mipSurface = new Surface(mipSize, mipSize);
		unsigned int *bits = static_cast<unsigned int*>(mipSurface->bits());
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
		
		texture->setMipSurface(i, mipSurface);
		mipSize /= 2;
	}
	
	return texture;
}	
	
int main()
{
	Texture *texture = makeMipMaps();
	texture->enableBilinearFiltering(true);

	RenderContext *context = new RenderContext();
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	renderTarget->setColorBuffer(colorBuffer);
	context->bindTarget(renderTarget);
	context->bindShader(new TextureVertexShader(), new TexturePixelShader());
	context->bindTexture(0, texture);
	TextureUniforms uniforms;
	uniforms.fMVPMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	context->bindUniforms(&uniforms, sizeof(uniforms));
	context->bindGeometry(kSquareVertices, 4, kSquareIndices, 6);
	context->submitDrawCommand();
	context->finish();
	
	return 0;
}
