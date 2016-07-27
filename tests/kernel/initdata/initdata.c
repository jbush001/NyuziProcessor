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

#include <stdio.h>

// This forces an initialized data region to ensure it is loaded properly.
// Writing to the region should cause a copy-on-write.
char str[32] = "Uryyb Jbeyq";

void rot13(char *str)
{
    char *c;

    for (c = str; *c; c++)
    {
        if (*c >= 'A' && *c <= 'Z')
            *c = ((*c - 'A' + 13) % 26) + 'A';
        else if (*c >= 'a' && *c <= 'z')
            *c = ((*c - 'a' + 13) % 26) + 'a';
    }
}

int main()
{
    // Reverse the string
    rot13(str);
    printf("%s\n", str);
}
