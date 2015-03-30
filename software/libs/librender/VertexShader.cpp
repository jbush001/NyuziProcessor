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



#include "VertexShader.h"

using namespace librender;

const veci16_t kStepVector = { 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60 };

VertexShader::VertexShader(int attribsPerVertex, int paramsPerVertex)
	:	fParamStepVector(kStepVector * splati(paramsPerVertex)),
		fAttribStepVector(kStepVector * splati(attribsPerVertex)),
		fParamsPerVertex(paramsPerVertex),
		fAttribsPerVertex(attribsPerVertex)
{
}

void VertexShader::processVertices(float *outParams, const float *attribs, const void *inUniforms, 
	int numVertices) const
{
	int mask;
	if (numVertices < 16)
		mask = (0xffff0000 >> numVertices) & 0xffff;
	else
		mask = 0xffff;

	// Gather from attribute buffer int packedAttribs buffer
	veci16_t attribPtr = fAttribStepVector + splati((unsigned int) attribs);
	vecf16_t packedAttribs[fAttribsPerVertex];
	for (int attrib = 0; attrib < fAttribsPerVertex; attrib++)
	{
		packedAttribs[attrib] = __builtin_nyuzi_gather_loadf_masked(attribPtr, mask); 
		attribPtr += splati(4);
	}

	vecf16_t packedParams[fParamsPerVertex];
	shadeVertices(packedParams, packedAttribs, inUniforms, mask);

	// Scatter packedParams back out to parameter buffer
	veci16_t paramPtr = fParamStepVector + splati((unsigned int) outParams);
	for (int param = 0; param < fParamsPerVertex; param++)
	{
		__builtin_nyuzi_scatter_storef_masked(paramPtr, packedParams[param], mask);
		paramPtr += splati(4);
	}
}

