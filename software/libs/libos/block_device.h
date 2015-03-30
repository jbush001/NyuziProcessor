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

//
// Virtual mass storage driver
//

#define BLOCK_SIZE 512

#ifdef __cplusplus
extern "C" {
#endif

// Read a single BLOCK_SIZE block from the given byte offset in the device into
// the passed buffer.
void read_block_device(unsigned int offset, void *ptr);

#ifdef __cplusplus
}
#endif

