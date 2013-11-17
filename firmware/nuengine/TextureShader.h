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

#ifndef __TEXTURE_SHADER_H
#define __TEXTURE_SHADER_H

#define BILINEAR_FILTERING 1

class TextureVertexShader : public VertexShader
{
public:
	TextureVertexShader(int width, int height)
		:	VertexShader(5, 6)
	{
		const float kAspectRatio = float(width) / float(height);
		const float kProjCoeff[4][4] = {
			{ 1.0f / kAspectRatio, 0.0f, 0.0f, 0.0f },
			{ 0.0f, kAspectRatio, 0.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f }
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
#if BILINEAR_FILTERING
		fSampler.setEnableBilinearFiltering(true);
#endif
	}
	
	virtual void shadePixels(const vecf16 inParams[16], vecf16 outColor[4],
		unsigned short mask)
	{
		fSampler.readPixels(inParams[0], inParams[1], mask, outColor);
	}
		
private:
	TextureSampler fSampler;
};

#endif

