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
// Validates near plane clipping by rendering triangles who's Z coordinate
// is less than one.
//

#include <math.h>
#include <schedule.h>
#include <stdlib.h>
#include <Matrix.h>
#include <RenderTarget.h>
#include <RenderContext.h>
#include "CheckerboardShader.h"
#include "room.h"

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
	context->bindShader(new CheckerboardVertexShader(), new CheckerboardPixelShader());

	context->bindGeometry(kRoomVertices, kNumRoomVertices, kRoomIndices, kNumRoomIndices);

	Matrix projectionMatrix = Matrix::getProjectionMatrix(kFbWidth, kFbHeight);
	Matrix modelViewMatrix = Matrix::getRotationMatrix(M_PI / 3, Vec3(0.0f, 1.0f, 0.0f));
	Matrix rotationMatrix = Matrix::getRotationMatrix(M_PI / 16, Vec3(0.0f, 1.0f, 0.0f));

	for (int frame = 0; frame < 1; frame++)
	{
		CheckerboardUniforms uniforms;
		uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
		context->bindUniforms(&uniforms, sizeof(uniforms));
		context->submitDrawCommand();
		context->finish();
		modelViewMatrix *= rotationMatrix;
	}
	
	return 0;
}
