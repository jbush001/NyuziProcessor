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


#define DRAW_TORUS 0
#define DRAW_CUBE 0
#define DRAW_TEAPOT 1
#define DRAW_TRIANGLE 0 

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include <Matrix.h>
#include <Rasterizer.h>
#include <RenderTarget.h>
#include <TextureSampler.h>
#include <RenderContext.h>
#include "PhongShader.h"
#include "TextureShader.h"
#if DRAW_TORUS 
	#include "torus.h"
#elif DRAW_CUBE
	#include "cube.h"
	#include "brick-texture.h"
#elif DRAW_TEAPOT
	#include "teapot.h"
#elif !DRAW_TRIANGLE
	#error Configure something to draw
#endif

using namespace render;

const int kFbWidth = 640;
const int kFbHeight = 480;

static float kTriangleVertices[] = {
	0.0, -0.9, 1.0, 0.0, 0.0, -1.0,
	0.9, 0.9, 1.0, 0.0, 0.0, -1.0,
	-0.9, 0.9, 1.0, 0.0, 0.0, -1.0
};

static int kTriangleIndices[] = { 0, 2, 1 };

void *operator new(size_t size, void *p)
{
	return p;
}
	
int main()
{
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	Surface *zBuffer = new (memalign(64, sizeof(Surface))) Surface(kFbWidth, kFbHeight);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setZBuffer(zBuffer);
	RenderContext *context = new RenderContext(renderTarget);
	
#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	VertexShader *vertexShader = new (memalign(64, sizeof(PhongVertexShader))) PhongVertexShader();
	PixelShader *pixelShader = new PhongPixelShader(renderTarget);
#else
	VertexShader *vertexShader = new (memalign(64, sizeof(TextureVertexShader))) TextureVertexShader();
	PixelShader *pixelShader = new TexturePixelShader(renderTarget);
#endif

	pixelShader->enableZBuffer(true);
	context->bindShader(vertexShader, pixelShader);

#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
	PhongUniforms *uniforms = new PhongUniforms;
#else
	TextureUniforms *uniforms = new TextureUniforms;
	uniforms->fTexture = new TextureSampler();
	uniforms->fTexture->bind(new (memalign(64, sizeof(Surface))) Surface(128, 128, (void*) kBrickTexture));
	uniforms->fTexture->setEnableBilinearFiltering(true);
#endif

	context->bindUniforms(uniforms);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	Matrix modelViewMatrix;
	Matrix rotationMatrix;

#if DRAW_TRIANGLE
	context->bindGeometry(kTriangleVertices, 3, kTriangleIndices, 3);
	// modelViewMatrix is identity
#elif DRAW_TORUS
	context->bindGeometry(kTorusVertices, kNumTorusVertices, kTorusIndices, kNumTorusIndices);
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.0f, 1.5f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f);
#elif DRAW_CUBE
	context->bindGeometry(kCubeVertices, kNumCubeVertices, kCubeIndices, kNumCubeIndices);
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.0f, 2.0f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f);
#elif DRAW_TEAPOT
	context->bindGeometry(kTeapotVertices, kNumTeapotVertices, kTeapotIndices, kNumTeapotIndices);
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.1f, 0.25f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI, -1.0f, 0.0f, 0.0f);
#endif
	
	rotationMatrix = Matrix::getRotationMatrix(M_PI / 8, 0.707f, 0.707f, 0.0f);

	for (int frame = 0; frame < 1; frame++)
	{
		uniforms->fMVPMatrix = projectionMatrix * modelViewMatrix;
#if DRAW_TORUS || DRAW_TEAPOT || DRAW_TRIANGLE
		uniforms->fNormalMatrix = modelViewMatrix.upper3x3();
#endif
		context->renderFrame();
		modelViewMatrix = modelViewMatrix * rotationMatrix;
	}
	
	return 0;
}
