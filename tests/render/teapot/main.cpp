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
// Render the Utah Teapot with a directional lighting model.
//

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include <Matrix.h>
#include <RenderTarget.h>
#include <RenderContext.h>
#include "PhongShader.h"
#include "teapot.h"

using namespace librender;

const int kFbWidth = 640;
const int kFbHeight = 480;
	
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
	context->bindShader(new PhongVertexShader(), new PhongPixelShader());

	PhongUniforms uniforms;
	uniforms.fLightVector[0] = 0.7071067811f;
	uniforms.fLightVector[1] = -0.7071067811f; 
	uniforms.fLightVector[2] = 0.0f;
	uniforms.fDirectional = 0.6f;		
	uniforms.fAmbient = 0.2f;

	context->bindGeometry(kTeapotVertices, kNumTeapotVertices, kTeapotIndices, kNumTeapotIndices);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	Matrix modelViewMatrix;
	Matrix rotationMatrix;
	modelViewMatrix = Matrix::getTranslationMatrix(Vec3(0.0f, -2.0f, -5.0f));
	modelViewMatrix *= Matrix::getScaleMatrix(20.0);
	rotationMatrix = Matrix::getRotationMatrix(M_PI / 16, Vec3(1, 1, 0));

	for (int frame = 0; frame < 1; frame++)
	{
		uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
		uniforms.fNormalMatrix = modelViewMatrix.upper3x3();
		context->bindUniforms(&uniforms, sizeof(uniforms));
		context->submitDrawCommand();
		context->finish();
		modelViewMatrix *= rotationMatrix;
	}
	
	return 0;
}
