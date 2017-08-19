//
// Copyright 2017 Jeff Bush
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

#include <stdio.h>

int main()
{
    printf("<%d>\n", 12345678); // CHECK: <12345678>
    printf("<%d>\n", -2);   // CHECK: <-2>
    printf("<%u>\n", 452345u), // CHECK: <452345>
    printf("<%u>\n", 4294967294u);  // CHECK: <4294967294>
    printf("<%Ld>\n", 37036629630ll); // CHECK: <37036629630>
    printf("<%Ld>\n", -37036629630ll); // CHECK: <-37036629630>
    printf("<%Lu>\n", 37036629630ull); // CHECK: <37036629630>
    printf("<%Lu>\n", 18446744036672921986ull); // CHECK: <18446744036672921986>
    printf("<%x>\n", 0x762); // CHECK: <762>
    printf("<%Lx>\n", 0xf947483738473843ull); // CHECK: <f947483738473843>
    printf("<%016Lx>\n", 0x123ull); // CHECK: <0000000000000123>
    printf("<%08d>\n", 1234); // CHECK: <00001234>
    printf("<%09x>\n", 0x847); // CHECK: <000000847>
    printf("<%8d>\n", 1234); // CHECK: <    1234>
    printf("<%9x>\n", 0x789); // CHECK: <      789>
    printf("<%s>\n", "foo");  // CHECK: <foo>
    printf("<%.4s>\n", "abcdefgh"); // CHECK: <abcd>
    // XXX padding not supported

    printf("<%g>\n", 1.5); // CHECK: <1.5>
    printf("<%f>\n", 2.25); // CHECK: <2.25>
    printf("<%f>\n", 0.5); // CHECK: <0.5>
    printf("<%f>\n", 4.0); // CHECK: <4.0>
    printf("<%c%c%c%c>\n", 'a', 'b', 'c', 'd'); // CHECK: <abcd>
}
