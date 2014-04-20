// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


#include "Debug.h"
#include "VertexShader.h"
#include "Core.h"

using namespace render;

const veci16 kStepVector = { 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60 };

VertexShader::VertexShader(int attribsPerVertex, int paramsPerVertex)
	:	fParamsPerVertex(paramsPerVertex),
		fParamStepVector(kStepVector * splati(paramsPerVertex)),
		fAttribsPerVertex(attribsPerVertex),
		fAttribStepVector(kStepVector * splati(attribsPerVertex))
{
}

void VertexShader::processVertices(float *outParams, const float *attribs, int numVertices) const
{
	int mask;
	if (numVertices < 16)
		mask = (0xffff0000 >> numVertices) & 0xffff;
	else
		mask = 0xffff;

	// Gather from attribute buffer int packedAttribs buffer
	veci16 attribPtr = fAttribStepVector + splati((unsigned int) attribs);
	vecf16 packedAttribs[fAttribsPerVertex];
	for (int attrib = 0; attrib < fAttribsPerVertex; attrib++)
	{
		packedAttribs[attrib] = __builtin_vp_gather_loadf_masked(attribPtr, mask); 
		attribPtr += splati(4);
	}

	vecf16 packedParams[fParamsPerVertex];
	shadeVertices(packedParams, packedAttribs, mask);

	// Perform perspective division
	vecf16 oneOverW = splatf(1.0) / packedParams[kParamW];
	packedParams[kParamX] *= oneOverW;
	packedParams[kParamY] *= oneOverW;

	veci16 paramPtr = fParamStepVector + splati((unsigned int) outParams);

	// Scatter packedParams back out to parameter buffer
	for (int param = 0; param < fParamsPerVertex; param++)
	{
		__builtin_vp_scatter_storef_masked(paramPtr, packedParams[param], mask);
		paramPtr += splati(4);
	}
}

