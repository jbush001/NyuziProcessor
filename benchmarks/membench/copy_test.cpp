// 
// Copyright 2013-2014 Jeff Bush
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

#define NUM_STRANDS 4

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

const int kTransferSize = 0x100000;
void * const region1Base = (void*) 0x200000;
void * const region2Base = (void*) 0x300000;

int main()
{
	veci16 *dest = (veci16*) region1Base + __builtin_vp_get_current_strand();
	veci16 *src = (veci16*) region2Base + __builtin_vp_get_current_strand();
	veci16 values = __builtin_vp_makevectori(0xdeadbeef);
	
	for (int i = 0; i < kTransferSize / (64 * 4); i++)
	{
		*dest = *src;
		dest += NUM_STRANDS;
		src += NUM_STRANDS;
	}
}
