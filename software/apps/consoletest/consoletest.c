//
// Copyright 2011-2017 Jeff Bush
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
#include <console.h>
#include <vga.h>

#define WHITE 0x90909090
#define BLACK 0

int main()
{
    char input_line[256];
    int got;

    console_init(init_vga(VGA_MODE_640x480), 640, 480);
    console_set_colors(WHITE, BLACK);
    console_puts("\n !\"#$%&'()*+,-./0123456789:;<=>?@[\\]^_`{|}~\n");
    console_puts(" ABCDEFGHIJKLMNOPQRSTUVWXYZ\n");
    console_puts(" abcdefghijklmnopqrstuvwxyz\n");
    console_puts(" AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz\n");
    console_puts(" The quick brown fox jumped over the lazy dog.\n");
    console_set_colors(BLACK, WHITE);
    console_puts(" Inverse text\n");
    console_set_colors(WHITE, BLACK);
    while (1)
    {
        console_puts("> ");
        got = console_read_line(input_line, sizeof(input_line));
        input_line[got] = '\0';
        printf("%s\n", input_line);
    }

    return 0;
}
