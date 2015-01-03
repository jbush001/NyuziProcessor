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


#include "ParameterInterpolator.h"

using namespace librender;

void ParameterInterpolator::setUpTriangle(
	float x0, float y0, float z0, 
	float x1, float y1, float z1,
	float x2, float y2, float z2)
{
	fOneOverZInterpolator.init(x0, y0, 1.0f / z0, x1, y1, 1.0f / z1, x2, y2, 1.0f / z2);
	fNumParams = 0;
	fX0 = x0;
	fY0 = y0;
	fZ0 = z0;
	fX1 = x1;
	fY1 = y1;
	fZ1 = z1;
	fX2 = x2;
	fY2 = y2;
	fZ2 = z2;
}

void ParameterInterpolator::setUpParam(int paramIndex, float c0, float c1, float c2)
{
	fParamOverZInterpolator[paramIndex].init(fX0, fY0, c0 / fZ0,
		fX1, fY1, c1 / fZ1,
		fX2, fY2, c2 / fZ2);
	if (paramIndex + 1 > fNumParams)
		fNumParams = paramIndex + 1;
}

void ParameterInterpolator::computeParams(vecf16_t x, vecf16_t y, vecf16_t params[],
	vecf16_t &outZValues) const
{
	// Perform perspective correct interpolation of parameters
	vecf16_t zValues = splatf(1.0f) / fOneOverZInterpolator.getValuesAt(x, y);
	for (int i = 0; i < fNumParams; i++)
		params[i] = fParamOverZInterpolator[i].getValuesAt(x, y) * zValues;

	outZValues = zValues;
}
