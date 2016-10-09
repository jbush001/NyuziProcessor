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

extern unsigned long long int __udivdi3(unsigned long long int dividend,
                                        unsigned long long int divisor);

// Signed 64-bit integer division
long long int __divdi3(long long int value1, long long int value2)
{
    int sign1 = value1 >> 63;
    int sign2 = value2 >> 63;

    // Take absolute values
    unsigned long long int u_value1 = (value1 ^ sign1) - sign1;
    unsigned long long int u_value2 = (value2 ^ sign2) - sign2;

    // Compute result sign
    sign1 ^= sign2;

    // Perform division (will call __udivsi3), then convert sign back
    return (__udivdi3(u_value1, u_value2) ^ sign1) - sign1;
}
