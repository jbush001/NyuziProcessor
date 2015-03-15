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
	
// All threads start execution here.
int main()
{
	if (__builtin_nyuzi_read_control_reg(0) != 0)
		workerThread();

	// Start worker threads
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);

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
