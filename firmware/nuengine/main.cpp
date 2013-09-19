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

const char kCheckerboard[] = {
	0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00,
	0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0xff,
	0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00,
	0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0xff
};

const int kNumCubeVertices = 24;
const float kCubeVertices[] = {
	// Front face
	0.5, 0.5, -0.5, 1.0, 0.0,
	-0.5, 0.5, -0.5, 1.0, 1.0,
	-0.5, -0.5, -0.5, 0.0, 1.0,
	0.5, -0.5, -0.5, 0.0, 0.0,

	// Right side
	0.5, -0.5, -0.5, 1.0, 0.0,
	0.5, -0.5, 0.5, 1.0, 1.0,
	0.5, 0.5, 0.5, 0.0, 1.0,
	0.5, 0.5, -0.5, 0.0, 0.0,

	// Left side
	-0.5, -0.5, -0.5, 0.0, 0.0,
	-0.5, 0.5, -0.5, 1.0, 0.0,
	-0.5, 0.5, 0.5, 1.0, 1.0,
	-0.5, -0.5, 0.5, 0.0, 1.0,

	// Back
	0.5, -0.5, 0.5, 0.0, 0.0,
	-0.5, -0.5, 0.5, 1.0, 0.0,
	-0.5, 0.5, 0.5, 1.0, 1.0,
	0.5, 0.5, 0.5, 0.0, 1.0,

	// Top
	-0.5, -0.5, -0.5, 0.0, 0.0,
	-0.5, -0.5, 0.5, 1.0, 0.0,
	0.5, -0.5, 0.5, 1.0, 1.0,
	0.5, -0.5, -0.5, 0.0, 1.0,

	// Bottom
	0.5, 0.5, -0.5, 0.0, 0.0,
	0.5, 0.5, 0.5, 1.0, 0.0,
	-0.5, 0.5, 0.5, 1.0, 1.0,
	-0.5, 0.5, -0.5, 0.0, 1.0
};

const int kNumCubeIndices = 36;
const int kCubeIndices[] = {
	0, 1, 2, 2, 3, 0,
	4, 5, 6, 6, 7, 4,
	8, 9, 10, 10, 11, 8,
	12, 13, 14, 14, 15, 12,
	16, 17, 18, 18, 19, 16,
	20, 21, 22, 22, 23, 20
};

const int kFbWidth = 640;
const int kFbHeight = 480;
const int kTilesPerRow = kFbWidth / kTileSize;
const int kMaxTileIndex = kTilesPerRow * ((kFbHeight / 64) + 1);
Barrier<4> gGeometryBarrier;
Barrier<4> gPixelBarrier;
volatile int gNextTileIndex = 0;
float *gVertexParams;
Surface gZBuffer(0, kFbWidth, kFbHeight);
Surface gColorBuffer(0x100000, kFbWidth, kFbHeight);
#if 0
	Surface texture((unsigned int) kCheckerboard, 4, 4);
#else
	extern char *kImage;
	Surface texture((unsigned int) kImage, 128, 128);
#endif

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

Matrix rotateXYZ(float x, float y, float z)
{
	float sinX = sin(x);
	float cosX = cos(x);
	float sinY = sin(y);
	float cosY = cos(y);
	float sinZ = sin(z);
	float cosZ = cos(z);

	float kMat1[] = {
		cosY * cosZ, cosZ * sinX * sinY - cosX * sinZ, cosX * cosZ * sinY + sinX * sinZ, 0,
		cosY * sinZ, cosX * cosZ + sinX * sinY * sinZ, -cosZ * sinX + cosX * sinY * sinZ, 0,
		-sinY, cosY * sinX, cosX * cosY, 0,
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
	renderTarget.setColorBuffer(&gColorBuffer);
	renderTarget.setZBuffer(&gZBuffer);
	ParameterInterpolator interp(kFbWidth, kFbHeight);
	TexturePixelShader pixelShader(&interp, &renderTarget);
	pixelShader.bindTexture(&texture);
	TextureVertexShader vertexShader;

	vertexShader.applyTransform(translate(0.0f, 0.0f, 1.5f));
	Matrix rotateStepMatrix = rotateXYZ(M_PI / 3.0f, M_PI / 7.0f, M_PI / 8.0f);
	
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
			if (gVertexParams == 0)
				gVertexParams = (float*) allocMem(512 * sizeof(float));
		
			vertexShader.applyTransform(rotateStepMatrix);
			vertexShader.processVertexBuffer(gVertexParams, kCubeVertices, kNumCubeVertices);
			gNextTileIndex = 0;
		}
		
		gGeometryBarrier.wait();
	
		//
		// Pixel phase
		//
		while (gNextTileIndex < kMaxTileIndex)
		{
			// Grab the next available tile to begin working on.
			int myTileIndex = __sync_fetch_and_add(&gNextTileIndex, 1);
			if (myTileIndex >= kMaxTileIndex)
				break;

			int tileX = (myTileIndex % kTilesPerRow) * kTileSize;
			int tileY = (myTileIndex / kTilesPerRow) * kTileSize;

			renderTarget.getColorBuffer()->clearTile(tileX, tileY, 0);
			if (pixelShader.isZBufferEnabled())
				renderTarget.getZBuffer()->clearTile(tileX, tileY, 0x7f800000);	// Infinity

			// Cycle through all triangles and attempt to render into this 
			// 64x64 tile.
			for (int vidx = 0; vidx < kNumCubeIndices; vidx += 3)
			{
				int offset0 = kCubeIndices[vidx] * numVertexParams;
				int offset1 = kCubeIndices[vidx + 1] * numVertexParams;
				int offset2 = kCubeIndices[vidx + 2] * numVertexParams;
			
				// XXX could do some trivial rejections here for triangles that
				// obviously aren't in this tile.
				float x0 = gVertexParams[offset0 + kParamX];
				float y0 = gVertexParams[offset0 + kParamY];
				float z0 = gVertexParams[offset0 + kParamZ];
				float x1 = gVertexParams[offset1 + kParamX];
				float y1 = gVertexParams[offset1 + kParamY];
				float z1 = gVertexParams[offset1 + kParamZ];
				float x2 = gVertexParams[offset2 + kParamX];
				float y2 = gVertexParams[offset2 + kParamY];
				float z2 = gVertexParams[offset2 + kParamZ];

				interp.setUpTriangle(x0, y0, z0, x1, y1, z1, x2, y2, z2);
				for (int paramI = 0; paramI < numVertexParams; paramI++)
				{
					interp.setUpParam(paramI, 
						gVertexParams[offset0 + paramI + 4],
						gVertexParams[offset1 + paramI + 4], 
						gVertexParams[offset2 + paramI + 4]);
				}

				rasterizer.rasterizeTriangle(&pixelShader, tileX, tileY,
					(int)(x0 * kFbWidth / 2 + kFbWidth / 2), 
					(int)(y0 * kFbHeight / 2 + kFbHeight / 2), 
					(int)(x1 * kFbWidth / 2 + kFbWidth / 2), 
					(int)(y1 * kFbHeight / 2 + kFbHeight / 2), 
					(int)(x2 * kFbWidth / 2 + kFbWidth / 2), 
					(int)(y2 * kFbHeight / 2 + kFbHeight / 2));
			}

			renderTarget.getColorBuffer()->flushTile(tileX, tileY);
		}

		gPixelBarrier.wait();
	}
	
	return 0;
}

Debug Debug::debug;
