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

#ifndef __UTILS_H
#define __UTILS_H

//
// Standard library functions, math, etc.
//

#include "vectypes.h"

#define M_PI 3.141579f

extern "C" {
	void memcpy(void *dest, const void *src, unsigned int length);
	void memset(void *dest, int value, unsigned int length);
	float fmod(float val1, float val2);
	float sin(float angle);
	float cos(float angle);
};

inline void dflush(unsigned int address)
{
	asm("dflush %0" : : "s" (address));
}

inline void __halt() __attribute__((noreturn));

inline void __halt()
{
	asm("setcr s0, 31");
	while (true)
		;
}
	
#endif
