//
// Copyright 2016 Jeff Bush
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

float __floatundisf(long long int a)
{
    int leadingZeroes = __builtin_clzll(a);
    if (leadingZeroes >= 32)
        return (float) (unsigned int)(a & 0xffffffff);
    else
        return ((float)(unsigned int)(a >> 32)) * 4294967296.0f;
}

