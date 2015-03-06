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
// Validate texture mapping by displaying a texture on the sides of a cube.
//

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include <Matrix.h>
#include <RenderTarget.h>
#include <Texture.h>
#include <RenderContext.h>
#include "TextureShader.h"
#include "cube.h"
#include "crate-texture.h"

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;
	
// All threads start execution here.
int main()
{
	if (__builtin_nyuzi_read_control_reg(0) != 0)
		workerThread();

	// Start worker threads
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);

	RenderContext *context = new RenderContext();
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(kFbWidth, kFbHeight, (void*) 0x200000);
	Surface *depthBuffer = new Surface(kFbWidth, kFbHeight);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setDepthBuffer(depthBuffer);
	context->bindTarget(renderTarget);
	context->enableDepthBuffer(true);
	context->bindShader(new TextureVertexShader(), new TexturePixelShader());
	context->bindGeometry(kCubeVertices, kNumCubeVertices, kCubeIndices, kNumCubeIndices);

	Texture *texture = new Texture();
	texture->setMipSurface(0, new Surface(512, 512, (void*) kCrateTexture));
	texture->enableBilinearFiltering(true);
	context->bindTexture(0, texture);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	Matrix modelViewMatrix;
	Matrix rotationMatrix;
	modelViewMatrix = Matrix::getTranslationMatrix(Vec3(0.0f, 0.0f, -3.0f));
	modelViewMatrix *= Matrix::getScaleMatrix(2.0f);
	modelViewMatrix *= Matrix::getRotationMatrix(M_PI / 3.5, Vec3(1, -1, 0));
	rotationMatrix = Matrix::getRotationMatrix(M_PI / 8, Vec3(1, 1, 0.0f));

	for (int frame = 0; frame < 1; frame++)
	{
		TextureUniforms uniforms;
		uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
		context->bindUniforms(&uniforms, sizeof(uniforms));
		context->submitDrawCommand();
		context->finish();
		modelViewMatrix *= rotationMatrix;
	}
	
	return 0;
}
