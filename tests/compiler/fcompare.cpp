// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 


#include <stdio.h>

void __attribute__ ((noinline)) test_compare(float a, float b)
{
    printf("a > b %d\n", a > b);
    printf("a >= b %d\n", a >= b);
    printf("a < b %d\n", a < b);
    printf("a <= b %d\n", a <= b);
    printf("a == b %d\n", a == b);
    printf("a != b %d\n", a != b);
}

int main()
{
    float values[] = { -2.0f, -1.0f, 0.0f, 1.0f, 2.0f, 0.0f/0.0f };

    for (int i = 0; i < 5; i++)
    {
        for (int j = 0; j < 5; j++)
        {
            printf("%d %d ", i, j);
            test_compare(i, j);
        }
    }
}

// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0
// CHECK: a > b 0
// CHECK: a >= b 0
// CHECK: a < b 1
// CHECK: a <= b 1
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 1
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 0
// CHECK: a == b 0
// CHECK: a != b 1
// CHECK: a > b 0
// CHECK: a >= b 1
// CHECK: a < b 0
// CHECK: a <= b 1
// CHECK: a == b 1
// CHECK: a != b 0