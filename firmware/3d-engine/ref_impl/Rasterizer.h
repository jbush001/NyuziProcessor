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

#ifndef __RASTERIZER_H
#define __RASTERIZER_H

#include "PixelShaderState.h"

class Rasterizer
{
public:
	Rasterizer();
	void rasterizeTriangle(PixelShaderState *shaderState, 
		int binLeft, int binTop,
		int x1, int y1, int x2, int y2, int x3, int y3);

private:
	void setupEdge(int left, int top, int x1, int y1, int x2, int y2, int &outAcceptEdgeValue, 
		int &outRejectEdgeValue, vec16<int> &outAcceptStepMatrix, 
		vec16<int> &outRejectStepMatrix);
	void subdivideTile( 
		int acceptCornerValue1, 
		int acceptCornerValue2, 
		int acceptCornerValue3,
		int rejectCornerValue1, 
		int rejectCornerValue2,
		int rejectCornerValue3,
		vec16<int> acceptStep1, 
		vec16<int> acceptStep2, 
		vec16<int> acceptStep3, 
		vec16<int> rejectStep1, 
		vec16<int> rejectStep2, 
		vec16<int> rejectStep3, 
		int tileSize,
		int left,
		int top);

	PixelShaderState *fShaderState;
};

#endif
