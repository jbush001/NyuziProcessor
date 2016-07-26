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

#include <vga.h>

int main()
{
    unsigned int x;
    unsigned int y;
    unsigned int *fb;

    fb = (unsigned int*) init_vga(VGA_MODE_640x480);

    for (y = 0; y < 480; y++)
    {
        for (x = 0; x < 640; x++)
            fb[y * 640 + x] = x > y ? 0xffff0000 : 0xff00ff00;
    }
}