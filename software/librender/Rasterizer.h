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


#pragma once

#include <stdint.h>
#include "ShaderFiller.h"

namespace librender
{

// Triangles are wound counter-clockwise
void fillTriangle(ShaderFiller &filler,
	int left, int top,
	int x1, int y1, int x2, int y2, int x3, int y3, 
	int clipRight, int clipBottom);

}

