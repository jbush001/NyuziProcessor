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

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include <Matrix.h>
#include <RenderTarget.h>
#include <TextureSampler.h>
#include <RenderContext.h>
#include "TextureShader.h"
#include "cube.h"
#include "crate-texture.h"

using namespace render;

const int kFbWidth = 640;
const int kFbHeight = 480;
	
int main()
{
	RenderContext *context = new RenderContext();
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	Surface *zBuffer = new Surface(kFbWidth, kFbHeight);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setZBuffer(zBuffer);
	context->bindTarget(renderTarget);
	context->enableZBuffer(true);
	context->bindShader(new TextureVertexShader(), new TexturePixelShader());

	TextureUniforms *uniforms = new TextureUniforms;
	uniforms->fTexture = new TextureSampler();
	uniforms->fTexture->bind(new Surface(512, 512, (void*) kCrateTexture), 0);
	uniforms->fTexture->setEnableBilinearFiltering(true);
	context->bindUniforms(uniforms);

	context->bindGeometry(kCubeVertices, kNumCubeVertices, kCubeIndices, kNumCubeIndices);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	Matrix modelViewMatrix;
	Matrix rotationMatrix;
	modelViewMatrix = Matrix::getTranslationMatrix(0.0f, 0.0f, 1.5f);
	modelViewMatrix = modelViewMatrix * Matrix::getRotationMatrix(M_PI / 3.5, 0.707f, 0.707f, 0.0f);
	rotationMatrix = Matrix::getRotationMatrix(M_PI / 8, 0.707f, 0.707f, 0.0f);

	for (int frame = 0; frame < 1; frame++)
	{
		uniforms->fMVPMatrix = projectionMatrix * modelViewMatrix;
		context->submitDrawCommand();
		context->finish();
		modelViewMatrix = modelViewMatrix * rotationMatrix;
	}
	
	return 0;
}
