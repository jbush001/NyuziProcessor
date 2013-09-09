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

#ifndef __RENDER_TARGET_H
#define __RENDER_TARGET_H

#include "Debug.h"
#include "vectypes.h"
#include "utils.h"
#include "Surface.h"

class RenderTarget
{
public:
	RenderTarget()
	    :   fColorBuffer(0),
	        fZBuffer(0)
	{
	}
	
	void setColorBuffer(Surface *buffer)
	{
	    fColorBuffer = buffer;
	}
	
	void setZBuffer(Surface *buffer)
	{
	    fZBuffer = buffer;
	}

	Surface *getColorBuffer()
	{
		return fColorBuffer;
	}

	Surface *getZBuffer()
	{
		return fZBuffer;
	}

private:
    Surface *fColorBuffer;
    Surface *fZBuffer;    
};

#endif
