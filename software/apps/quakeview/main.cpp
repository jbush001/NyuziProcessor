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

#include <keyboard.h>
#include <RenderContext.h>
#include <schedule.h>
#include <SIMDMath.h>
#include <stdio.h>
#include <Surface.h>
#include "PakFile.h"
#include "Render.h"
#include "TextureShader.h"

using namespace librender;

enum Button
{
	kUpArrow,
	kDownArrow,
	kRightArrow,
	kLeftArrow,
	kUKey,
	kDKey
};

namespace 
{

Vec3 gCameraPos(480, -352, 88);
const Vec3 kUpVector(0, 0, 1);
float gFacingAngle = M_PI / 2;
Vec3 gFacingVector(cos(gFacingAngle), sin(gFacingAngle), 0);
bool gKeyPressed[6] = { false, false, false, false, false, false };
bool gWireframeRendering = false;
bool gBilinearFiltering = true;

void processKeyboardEvents()
{
	// Consume as many keyboard events as are available.
	while (true)
	{
		unsigned int keyCode = pollKeyboard();
		if (keyCode == 0xffffffff)
			break;

		bool pressed = (keyCode & KBD_PRESSED) ? true : false;
		switch (keyCode & 0xff)
		{
			case KBD_RIGHTARROW:
				gKeyPressed[kRightArrow] = pressed;
				break;
			case KBD_LEFTARROW:
				gKeyPressed[kLeftArrow] = pressed;
				break;

			case KBD_UPARROW:
				gKeyPressed[kUpArrow] = pressed;
				break;

			case KBD_DOWNARROW:
				gKeyPressed[kDownArrow] = pressed;
				break;

			case 'u':
				gKeyPressed[kUKey] = pressed;
				break;
			
			case 'd':
				gKeyPressed[kDKey] = pressed;
				break;
				
			// Toggle gWireframeRendering
			case 'w':
				if (keyCode & KBD_PRESSED)
					gWireframeRendering = !gWireframeRendering;

				break;
			
			// Toggle gBilinearFiltering filtering
			case 'b':
				if (keyCode & KBD_PRESSED)
					gBilinearFiltering = !gBilinearFiltering;

				break;
			
		}
	}

	// Handle movement
	if (gKeyPressed[kRightArrow])
	{
		gFacingAngle -= M_PI / 16;
		if (gFacingAngle < 0)
			gFacingAngle += M_PI * 2;
		
		gFacingVector = Vec3(cos(gFacingAngle), sin(gFacingAngle), 0);
	}
	else if (gKeyPressed[kLeftArrow])
	{
		gFacingAngle += M_PI / 16;
		if (gFacingAngle > M_PI * 2)
			gFacingAngle -= M_PI * 2;

		gFacingVector = Vec3(cos(gFacingAngle), sin(gFacingAngle), 0);
	}
		
	if (gKeyPressed[kUpArrow])
		gCameraPos = gCameraPos + gFacingVector * 30;
	else if (gKeyPressed[kDownArrow])
		gCameraPos = gCameraPos - gFacingVector * 30;
	
	if (gKeyPressed[kUKey])
		gCameraPos = gCameraPos + Vec3(0, 0, 30);
	else if (gKeyPressed[kDKey])
		gCameraPos = gCameraPos + Vec3(0, 0, -30);
}

}

// All threads start execution here.
int main()
{
	if (__builtin_nyuzi_read_control_reg(0) != 0)
		workerThread();
	
	// Set kUpVector render state
	RenderContext *context = new RenderContext(0x1000000);
	RenderTarget *renderTarget = new RenderTarget();
	Surface *colorBuffer = new Surface(FB_WIDTH, FB_HEIGHT, (void*) 0x200000);
	Surface *zBuffer = new Surface(FB_WIDTH, FB_HEIGHT);
	renderTarget->setColorBuffer(colorBuffer);
	renderTarget->setDepthBuffer(zBuffer);
	context->bindTarget(renderTarget);
	context->enableDepthBuffer(true);
	context->bindShader(new TextureShader());

	// Read resources
	PakFile pak;
	pak.open("pak0.pak");
	pak.readBsp("maps/e1m1.bsp");
	Texture *atlasTexture = pak.getTexture();
	setBspData(pak.getBspTree(), pak.getPvsList(), pak.getBspTree() + pak.getNumInteriorNodes(), 
		pak.getNumLeaves(), atlasTexture);

	// Start worker threads
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);
	
	TextureUniforms uniforms;
	Matrix projectionMatrix = Matrix::getProjectionMatrix(FB_WIDTH, FB_HEIGHT);
	
	for (int frame = 0; ; frame++)
	{
		processKeyboardEvents();

		context->enableWireframeMode(gWireframeRendering);
		atlasTexture->enableBilinearFiltering(gBilinearFiltering);

		// Set up rendering
		Matrix modelViewMatrix = Matrix::lookAt(gCameraPos, gCameraPos + gFacingVector, kUpVector);
		uniforms.fMVPMatrix = projectionMatrix * modelViewMatrix;
		context->bindUniforms(&uniforms, sizeof(uniforms));

		// Enqueue rendering commands
		renderScene(context, gCameraPos);

		// Execute rendering commannds
		int startInstructions = __builtin_nyuzi_read_control_reg(6);
		context->finish();
		printf("rendered frame in %d instructions.\n", __builtin_nyuzi_read_control_reg(6) 
			- startInstructions);
	}
}
