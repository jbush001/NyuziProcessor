// 
// Copyright 2013 Jeff Bush
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

#include "assert.h"
#include "Barrier.h"
#include "Debug.h"
#include "Matrix.h"
#include "ParameterInterpolator.h"
#include "PixelShader.h"
#include "Rasterizer.h"
#include "RenderTarget.h"
#include "TextureSampler.h"
#include "utils.h"
#include "VertexShader.h"

class TextureVertexShader : public VertexShader
{
public:
	TextureVertexShader()
		:	VertexShader(5, 6)
	{
		const float kAspectRatio = 640.0f / 480.0f;
		const float kProjCoeff[] = {
			1.0f / kAspectRatio, 0.0f, 0.0f, 0.0f,
			0.0f, kAspectRatio, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
		};

		fProjectionMatrix = Matrix(kProjCoeff);
		fMVPMatrix = fProjectionMatrix;
	}
	
	void applyTransform(const Matrix &mat)
	{
		fModelViewMatrix = fModelViewMatrix * mat;
		fMVPMatrix = fProjectionMatrix * fModelViewMatrix;
	}

	void shadeVertices(vecf16 outParams[kMaxVertexAttribs],
		const vecf16 inAttribs[kMaxVertexAttribs], int mask)
	{
		// Multiply by mvp matrix
		vecf16 coord[4];
		for (int i = 0; i < 3; i++)
			coord[i] = inAttribs[i];
			
		coord[3] = splatf(1.0f);
		fMVPMatrix.mulVec(outParams, coord); 

		// Copy remaining parameters
		outParams[4] = inAttribs[3];
		outParams[5] = inAttribs[4];
	}
	
private:
	Matrix fMVPMatrix;
	Matrix fProjectionMatrix;
	Matrix fModelViewMatrix;
};

class TexturePixelShader : public PixelShader
{
public:
	TexturePixelShader(ParameterInterpolator *interp, RenderTarget *target)
		:	PixelShader(interp, target)
	{}
	
	void bindTexture(Surface *surface)
	{
		fSampler.bind(surface);
		fSampler.setEnableBilinearFiltering(true);
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask)
	{
		fSampler.readPixels(inParams[0], inParams[1], mask, outColor);
	}
		
private:
	TextureSampler fSampler;
};

const int kMaxTileIndex = (640 / 64) * ((480 / 64) + 1);
int nextTileIndex = 0;
extern char *kImage;
const int kFbWidth = 640;
const int kFbHeight = 480;
Barrier<4> gGeometryBarrier;
Barrier<4> gPixelBarrier;
const int gNumVertices = 36;
float gVertexParams[512];

const float kCube[] = {
	// Front face
	0.5, 0.5, -0.5, 1.0, 0.0,
	-0.5, 0.5, -0.5, 1.0, 1.0,
	-0.5, -0.5, -0.5, 0.0, 1.0,

	-0.5, -0.5, -0.5, 0.0, 1.0,
	0.5, -0.5, -0.5, 0.0, 0.0,
	0.5, 0.5, -0.5, 1.0, 0.0,

	// Right side
	0.5, -0.5, -0.5, 1.0, 0.0,
	0.5, -0.5, 0.5, 1.0, 1.0,
	0.5, 0.5, 0.5, 0.0, 1.0,

	0.5, 0.5, 0.5, 0.0, 1.0,
	0.5, 0.5, -0.5, 0.0, 0.0,
	0.5, -0.5, -0.5, 1.0, 0.0,

	// Left side
	-0.5, -0.5, -0.5, 0.0, 0.0,
	-0.5, 0.5, -0.5, 1.0, 0.0,
	-0.5, 0.5, 0.5, 1.0, 1.0,

	-0.5, 0.5, 0.5, 0.0, 0.0,
	-0.5, -0.5, 0.5, 1.0, 0.0,
	-0.5, -0.5, -0.5, 1.0, 1.0,

	// Back
	0.5, -0.5, 0.5, 0.0, 0.0,
	-0.5, -0.5, 0.5, 1.0, 0.0,
	-0.5, 0.5, 0.5, 1.0, 1.0,

	-0.5, 0.5, 0.5, 0.0, 0.0,
	0.5, 0.5, 0.5, 1.0, 0.0,
	0.5, -0.5, 0.5, 1.0, 1.0,

	// Top
	-0.5, -0.5, -0.5, 0.0, 0.0,
	-0.5, -0.5, 0.5, 1.0, 0.0,
	0.5, -0.5, 0.5, 1.0, 1.0,

	0.5, -0.5, 0.5, 0.0, 0.0,
	0.5, -0.5, -0.5, 1.0, 0.0,
	-0.5, -0.5, -0.5, 1.0, 1.0,

	// Bottom
	0.5, 0.5, -0.5, 0.0, 0.0,
	0.5, 0.5, 0.5, 1.0, 0.0,
	-0.5, 0.5, 0.5, 1.0, 1.0,

	-0.5, 0.5, 0.5, 0.0, 0.0,
	-0.5, 0.5, -0.5, 1.0, 0.0,
	0.5, 0.5, -0.5, 1.0, 1.0
};

Matrix translate(float x, float y, float z)
{
	float kValues[] = {
		1.0f, 0.0f, 0.0f, x, 
		0.0f, 1.0f, 0.0f, y, 
		0.0f, 0.0f, 1.0f, z, 
		0.0f, 0.0f, 0.0f, 1.0f, 
	};

	return Matrix(kValues);
}

Matrix rotateX()
{
	float sin = 0.19509032201f;	// sin(pi / 16)
	float cos = 0.9807852804f;	// cos(pi / 16)

	float kMat1[] = {
		1, 0, 0, 0,
		0, cos, sin, 0,
		0, -sin, cos, 0, 
		0, 0, 0, 1
	};
	
	return Matrix(kMat1);
}

Matrix rotateY()
{
	float sin = 0.19509032201f;	// sin(pi / 16)
	float cos = 0.9807852804f;	// cos(pi / 16)

	float kMat1[] = {
		cos, 0, sin, 0,
		0, 1, 0, 0,
		-sin, 0, cos, 0, 
		0, 0, 0, 1
	};
	
	return Matrix(kMat1);
}

Matrix rotateZ()
{
	float sin = 0.19509032201f;	// sin(pi / 16)
	float cos = 0.9807852804f;	// cos(pi / 16)

	float kMat1[] = {
		cos, -sin, 0, 0,
		sin, cos, 0, 0,
		0, 0, 1, 0, 
		0, 0, 0, 1
	};
	
	return Matrix(kMat1);
}

//
// All threads start execution here
//
int main()
{
	Rasterizer rasterizer;
	RenderTarget renderTarget;
	Surface colorBuffer(0x100000, kFbWidth, kFbHeight);
	Surface zBuffer(0x240000, kFbWidth, kFbHeight);
	renderTarget.setColorBuffer(&colorBuffer);
	renderTarget.setZBuffer(&zBuffer);
	ParameterInterpolator interp(kFbWidth, kFbHeight);
	Surface texture((unsigned int) kImage, 128, 128);
	TexturePixelShader pixelShader(&interp, &renderTarget);
	pixelShader.bindTexture(&texture);
	TextureVertexShader vertexShader;

	vertexShader.applyTransform(translate(0.0f, 0.0f, 1.5f));
	vertexShader.applyTransform(rotateX());
	Matrix rotateStepMatrix = rotateY();
	vertexShader.applyTransform(rotateZ());

//	pixelShader.enableZBuffer(true);
//	pixelShader.enableBlend(true);

	int numVertexParams = vertexShader.getNumParams();

	for (int frame = 0; frame < 1; frame++)
	{
		//
		// Geometry phase
		//
		if (__builtin_vp_get_current_strand() == 0)
		{
			vertexShader.applyTransform(rotateStepMatrix);
			vertexShader.processVertexBuffer(gVertexParams, kCube, gNumVertices);
		}
		
		gGeometryBarrier.wait();
	
		//
		// Pixel phase
		//
		nextTileIndex = 0;
		while (nextTileIndex < kMaxTileIndex)
		{
			// Grab the next available tile to begin working on.
			int myTileIndex = __sync_fetch_and_add(&nextTileIndex, 1);
			if (myTileIndex >= kMaxTileIndex)
				break;

			unsigned int tileXI, tileYI;
			udiv(myTileIndex, 10, tileYI, tileXI);
			int tileX = tileXI * 64;
			int tileY = tileYI * 64;

			renderTarget.getColorBuffer()->clearTile(tileX, tileY, 0);
			if (pixelShader.isZBufferEnabled())
				renderTarget.getZBuffer()->clearTile(tileX, tileY, 0x7f800000);	// Infinity

			// Cycle through all triangles and attempt to render into this 
			// 64x64 tile.
			float *params = gVertexParams;
			for (int vidx = 0; vidx < gNumVertices; vidx += 3)
			{
				// XXX could do some trivial rejections here for triangles that
				// obviously aren't in this tile.
				float x0 = params[kParamX];
				float y0 = params[kParamY];
				float z0 = params[kParamZ];
				float x1 = params[numVertexParams + kParamX];
				float y1 = params[numVertexParams + kParamY];
				float z1 = params[numVertexParams + kParamZ];
				float x2 = params[numVertexParams * 2 + kParamX];
				float y2 = params[numVertexParams * 2 + kParamY];
				float z2 = params[numVertexParams * 2 + kParamZ];

				interp.setUpTriangle(x0, y0, z0, x1, y1, z1, x2, y2, z2);
				for (int paramI = 0; paramI < numVertexParams; paramI++)
				{
					interp.setUpParam(paramI, 
						params[paramI + 4],
						params[numVertexParams + paramI + 4], 
						params[numVertexParams * 2 + paramI + 4]);
				}

				rasterizer.rasterizeTriangle(&pixelShader, tileX, tileY,
					(int)(x0 * kFbWidth / 2 + kFbWidth / 2), 
					(int)(y0 * kFbHeight / 2 + kFbHeight / 2), 
					(int)(x1 * kFbWidth / 2 + kFbWidth / 2), 
					(int)(y1 * kFbHeight / 2 + kFbHeight / 2), 
					(int)(x2 * kFbWidth / 2 + kFbWidth / 2), 
					(int)(y2 * kFbHeight / 2 + kFbHeight / 2));

				params += numVertexParams * 3;
			}

			renderTarget.getColorBuffer()->flushTile(tileX, tileY);
		}

		gPixelBarrier.wait();
	}
	
	return 0;
}

Debug Debug::debug;
