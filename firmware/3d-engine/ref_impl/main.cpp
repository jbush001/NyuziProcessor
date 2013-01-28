// 
// Copyright 2011-2013 Jeff Bush
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

#include "Rasterizer.h"
#include "PixelShaderState.h"
#include "PrimitiveAssembly.h"

int main(int argc, const char *argv[])
{
	PixelShader shader;
	OutputBuffer outputBuffer(256, 256);
	PixelShaderState pss(&outputBuffer);

	pss.setShader(&shader);
	Vertex vertices[3] = {
		{ { 0.3, 0.1, 0.4 }, { 1.0, 0.0, 0.0 } },
		{ { 0.9, 0.5, 0.4 }, { 0.0, 1.0, 0.0 } },
		{ { 0.1, 0.9, 0.4 }, { 0.0, 0.0, 1.0 } },
	};

	// Fill each bin
	for (int tileX = 0; tileX < outputBuffer.getWidth(); tileX += 64)
	{
		for (int tileY = 0; tileY < outputBuffer.getHeight(); tileY += 64)
		{
			renderTriangle(tileX, tileY, 3, vertices, &pss, 
				outputBuffer.getWidth(), outputBuffer.getHeight());
		}
	}
	
	outputBuffer.writeImage("image.raw");
	pss.printStats();
}
