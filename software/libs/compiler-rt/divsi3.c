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

extern unsigned int __udivsi3(unsigned int dividend, unsigned int divisor);

// Signed 32-bit integer division
int __divsi3(int value1, int value2)
{
    int sign1 = value1 >> 31;
    int sign2 = value2 >> 31;

    // Take absolute values
    unsigned int u_value1 = (value1 ^ sign1) - sign1;
    unsigned int u_value2 = (value2 ^ sign2) - sign2;

    // Compute result sign
    sign1 ^= sign2;

    // Perform division (will call __udivsi3), then convert sign back
    return (__udivsi3(u_value1, u_value2) ^ sign1) - sign1;
}
