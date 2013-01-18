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

int main(int argc, const char *argv[])
{
	Rasterizer rasterizer;
	PixelShader shader;
	OutputBuffer outputBuffer(256, 256);
	PixelShaderState pss(&outputBuffer);

	float x1 = 0.3;
	float y1 = 0.1;
	float z1 = 0.4;
	float x2 = 0.9;
	float y2 = 0.5;
	float z2 = 0.4;
	float x3 = 0.1;
	float y3 = 0.9;
	float z3 = 0.4;

	pss.setUpTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3, &shader);
	pss.setUpParam(0, 1.0, 0.0, 0.0);	// R
	pss.setUpParam(1, 0.0, 1.0, 0.0);	// G
	pss.setUpParam(2, 0.0, 0.0, 1.0);	// B

	for (int x = 0; x < outputBuffer.getWidth() / 64; x++)
	{
		for (int y = 0; y < outputBuffer.getHeight() / 64; y++)
		{
			// Render each bin
			rasterizer.rasterizeTriangle(&pss, 
				x * 64, y * 64,
				(int)(x1 * outputBuffer.getWidth()), 
				(int)(y1 * outputBuffer.getHeight()), 
				(int)(x2 * outputBuffer.getWidth()), 
				(int)(y2 * outputBuffer.getHeight()), 
				(int)(x3 * outputBuffer.getWidth()), 
				(int)(y3 * outputBuffer.getHeight()));
		}
	}
	
	outputBuffer.writeImage("image.raw");
	pss.printStats();
}
