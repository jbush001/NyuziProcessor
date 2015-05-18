// 
// Copyright 2015 Jeff Bush
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


#include <stdio.h>
#include <SIMDMath.h>
#include <RenderContext.h>
#include <Surface.h>
#include <schedule.h>
#include "PakFile.h"
#include "TextureShader.h"

using namespace librender;

//#define DISPLAY_ATLAS 1

namespace 
{

void makeWrappingTexture(PakFile *file, int textureId, RenderBuffer &vertices, RenderBuffer &indices)
{
	float left;
	float bottom;
	float width;
	float height;
	
	if (textureId < 0)
	{
		left = 0;
		bottom = 0;
		width = 1;
		height = 1;
	}
	else
		file->getTextureLocation(textureId, left, bottom, width, height);
	
	printf("atlas entry is %g %g %g %g\n", left, bottom, width, height);
	
	float *vdata = new float[kTotalAttrs * 4];
	float *vptr = vdata;
	*vptr++ = -1.0;
	*vptr++ = 1.0;
	*vptr++ = -1.0;
	*vptr++ = left;
	*vptr++ = bottom;
	*vptr++ = width;
	*vptr++ = height;
	*vptr++ = 0.0;
	*vptr++ = 4.0;

	*vptr++ = -1.0;
	*vptr++ = -1.0;
	*vptr++ = -1.0;
	*vptr++ = left;
	*vptr++ = bottom;
	*vptr++ = width;
	*vptr++ = height;
	*vptr++ = 0.0;
	*vptr++ = 0.0;

	*vptr++ = 1.0;
	*vptr++ = -1.0;
	*vptr++ = -1.0;
	*vptr++ = left;
	*vptr++ = bottom;
	*vptr++ = width;
	*vptr++ = height;
	*vptr++ = 4.0;
	*vptr++ = 0.0;

	*vptr++ = 1.0;
	*vptr++ = 1.0;
	*vptr++ = -1.0;
	*vptr++ = left;
	*vptr++ = bottom;
	*vptr++ = width;
	*vptr++ = height;
	*vptr++ = 4.0;
	*vptr++ = 4.0;

	vertices.setData(vdata, 4, kTotalAttrs * sizeof(float));
	
	int *idata = new int[6];
	idata[0] = 0;
	idata[1] = 1;
	idata[2] = 2;
	idata[3] = 2;
	idata[4] = 3;
	idata[5] = 0;
	
	indices.setData(idata, 6, sizeof(int));
}

}

// All threads start execution here.
int main()
{
	if (__builtin_nyuzi_read_control_reg(0) != 0)
		workerThread();
	
	// Set up render state
	RenderContext *context = new RenderContext(0x1000000);
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(FB_WIDTH, FB_HEIGHT, (void*) 0x200000);
	Surface *zBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setDepthBuffer(zBuffer);
	context->bindTarget(renderTarget);
	context->enableDepthBuffer(true);
	context->bindShader(new TextureShader());
	
	PakFile pak;
	
	pak.open("pak0.pak");
	pak.readBsp("maps/e1m1.bsp");

	context->bindTexture(0, pak.getTexture());
	context->enableWireframeMode(false);

	// Start worker threads
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);
	
	TextureUniforms uniforms;
	Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);


	printf("*** begin render ***\n");
	Vec3 cameraPos(544, 288, 32);
	for (int frame = 0; ; frame++)
	{
#if DISPLAY_ATLAS	
		context->bindUniforms(&uniforms, sizeof(uniforms));
#else	
		Matrix modelViewMatrix = Matrix::lookAt(cameraPos, cameraPos + Vec3(cos(frame * 3.14 / 10), 
			sin(frame * 3.14 / 10), 0), Vec3(0, 0, 1));
		uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
		context->bindUniforms(&uniforms, sizeof(uniforms));
#endif

#if DISPLAY_ATLAS
		RenderBuffer vertices;
		RenderBuffer indices;
		makeWrappingTexture(&pak, frame, vertices, indices);
		context->bindGeometry(&vertices, &indices);
		context->submitDrawCommand();
#else
		for (int i = 900; i < 1200; i++)
		{
			const RenderBuffer *vertexBuf;
			const RenderBuffer *indexBuf;
			pak.getLeaf(i, &vertexBuf, &indexBuf);
			context->bindGeometry(vertexBuf, indexBuf);
			context->submitDrawCommand();
		}
#endif
		int startInstructions = __builtin_nyuzi_read_control_reg(6);
		context->finish();
		printf("rendered frame in %d instructions\n", __builtin_nyuzi_read_control_reg(6) 
			- startInstructions);
	}
}
