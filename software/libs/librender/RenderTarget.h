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

#include "SIMDMath.h"
#include "Surface.h"

namespace librender
{

//
// A set of surfaces to render to.
//
class RenderTarget
{
public:
	void setColorBuffer(Surface *buffer)
	{
	    fColorBuffer = buffer;
	}
	
	void setDepthBuffer(Surface *buffer)
	{
	    fDepthBuffer = buffer;
	}

	Surface *getColorBuffer()
	{
		return fColorBuffer;
	}

	Surface *getDepthBuffer()
	{
		return fDepthBuffer;
	}

private:
    Surface *fColorBuffer = nullptr;
    Surface *fDepthBuffer = nullptr;    
};

}
