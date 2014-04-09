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

#include "vectypes.h"
#include "PixelShader.h"

namespace render
{

//
// The basic approach is based on this article: 
// http://www.drdobbs.com/parallel/rasterization-on-larrabee/217200602
// Which in turn is derived from the paper "Hierarchical polygon tiling with 
// coverage masks" Proceedings of ACM SIGGRAPH 93, Ned Greene.
//

class Rasterizer
{
public:
	// maxX and maxY must be a multiple of four
	Rasterizer(int maxX, int maxY);
	void fillTriangle(PixelShader *shader, 
		int left, int top,
		int x1, int y1, int x2, int y2, int x3, int y3);

private:
	void setupEdge(int left, int top, int x1, int y1, int x2, int y2, 
		int &outAcceptEdgeValue, int &outRejectEdgeValue, veci16 &outAcceptStepMatrix, 
		veci16 &outRejectStepMatrix);
	void subdivideTile( 
		int acceptCornerValue1, 
		int acceptCornerValue2, 
		int acceptCornerValue3,
		int rejectCornerValue1, 
		int rejectCornerValue2,
		int rejectCornerValue3,
		veci16 acceptStep1, 
		veci16 acceptStep2, 
		veci16 acceptStep3, 
		veci16 rejectStep1, 
		veci16 rejectStep2, 
		veci16 rejectStep3, 
		int tileSize,
		int left,
		int top);

	PixelShader *fShader;
	int fMaxX;
	int fMaxY;
};

}

#endif
