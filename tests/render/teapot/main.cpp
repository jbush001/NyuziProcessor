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
