//
// Copyright 2018 Jeff Bush
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

#include <uart.h>

int main()
{
    while (1)
    {
        unsigned ch = read_uart();
        if (ch >= 'A' && ch <= 'Z')
            write_uart(ch + ('a' - 'A'));
        else
            write_uart(ch);

        if (ch == '\n')
            break;
    }

    return 0;
}
