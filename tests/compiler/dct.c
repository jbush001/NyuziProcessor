/******************************************************************************
** This file is part of the jpegant project.
**
** Copyright (C) 2009-2013 Vladimir Antonenko
**
** This program is free software; you can redistribute it and/or modify it
** under the terms of the GNU General Public License as published by the
** Free Software Foundation; either version 2 of the License,
** or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
** See the GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License along
** with this program; if not, write to the Free Software Foundation, Inc.
******************************************************************************/

#include <stdio.h>

/******************************************************************************
**  dct
**  --------------------------------------------------------------------------
**  Fast DCT - Discrete Cosine Transform.
**  This function converts 8x8 pixel block into frequencies.
**  Lowest frequencies are at the upper-left corner.
**  The input and output could point at the same array, in this case the data
**  will be overwritten.
**  
**  ARGUMENTS:
**      pixels  - 8x8 pixel array;
**      data    - 8x8 freq block;
**
**  RETURN: -
******************************************************************************/
void dct(short pixels[8][8], short data[8][8])
{
        short rows[8][8];
        unsigned          i;

        static const short // Ci = cos(i*PI/16)*(1 << 14);
                C1 = 16070,
                C2 = 15137,
                C3 = 13623,
                C4 = 11586,
                C5 = 9103,
                C6 = 6270,
                C7 = 3197;

        // simple but fast DCT - 22*16 multiplication 28*16 additions and 8*16 shifts.

        /* transform rows */
        for (i = 0; i < 8; i++)
        {
                short s07,s16,s25,s34,s0734,s1625;
                short d07,d16,d25,d34,d0734,d1625;

                s07 = pixels[i][0] + pixels[i][7];
                d07 = pixels[i][0] - pixels[i][7];
                s16 = pixels[i][1] + pixels[i][6];
                d16 = pixels[i][1] - pixels[i][6];
                s25 = pixels[i][2] + pixels[i][5];
                d25 = pixels[i][2] - pixels[i][5];
                s34 = pixels[i][3] + pixels[i][4];
                d34 = pixels[i][3] - pixels[i][4];

                rows[i][1] = (C1*d07 + C3*d16 + C5*d25 + C7*d34) >> 14;
                rows[i][3] = (C3*d07 - C7*d16 - C1*d25 - C5*d34) >> 14;
                rows[i][5] = (C5*d07 - C1*d16 + C7*d25 + C3*d34) >> 14;
                rows[i][7] = (C7*d07 - C5*d16 + C3*d25 - C1*d34) >> 14;

                s0734 = s07 + s34;
                d0734 = s07 - s34;
                s1625 = s16 + s25;
                d1625 = s16 - s25;

                rows[i][0] = (C4*(s0734 + s1625)) >> 14;
                rows[i][4] = (C4*(s0734 - s1625)) >> 14;

                rows[i][2] = (C2*d0734 + C6*d1625) >> 14;
                rows[i][6] = (C6*d0734 - C2*d1625) >> 14;
        }

        /* transform columns */
        for (i = 0; i < 8; i++)
        {
                short s07,s16,s25,s34,s0734,s1625;
                short d07,d16,d25,d34,d0734,d1625;

                s07 = rows[0][i] + rows[7][i];
                d07 = rows[0][i] - rows[7][i];
                s16 = rows[1][i] + rows[6][i];
                d16 = rows[1][i] - rows[6][i];
                s25 = rows[2][i] + rows[5][i];
                d25 = rows[2][i] - rows[5][i];
                s34 = rows[3][i] + rows[4][i];
                d34 = rows[3][i] - rows[4][i];

                data[1][i] = (C1*d07 + C3*d16 + C5*d25 + C7*d34) >> 16;
                data[3][i] = (C3*d07 - C7*d16 - C1*d25 - C5*d34) >> 16;
                data[5][i] = (C5*d07 - C1*d16 + C7*d25 + C3*d34) >> 16;
                data[7][i] = (C7*d07 - C5*d16 + C3*d25 - C1*d34) >> 16;

                s0734 = s07 + s34;
                d0734 = s07 - s34;
                s1625 = s16 + s25;
                d1625 = s16 - s25;

                data[0][i] = (C4*(s0734 + s1625)) >> 16;
                data[4][i] = (C4*(s0734 - s1625)) >> 16;

                data[2][i] = (C2*d0734 + C6*d1625) >> 16;
                data[6][i] = (C6*d0734 - C2*d1625) >> 16;
        }
}

int main()
{
	short pixels[8][8] = {
		{ 0x0000, 0x008c, 0x00bd, 0x00ee, 0x011f, 0x0150, 0x0181, 0x01b2 },
		{ 0x001b, 0x004c, 0x0133, 0x0164, 0x0195, 0x01c6, 0x01f7, 0x0228 },
		{ 0x0036, 0x00c2, 0x0098, 0x01da, 0x020b, 0x023c, 0x026d, 0x029e },
		{ 0x0051, 0x0082, 0x010e, 0x00e4, 0x0281, 0x02b2, 0x02e3, 0x0314 },
		{ 0x006c, 0x00f8, 0x0184, 0x015a, 0x0130, 0x0328, 0x0359, 0x038a },
		{ 0x0087, 0x00b8, 0x00e9, 0x01d0, 0x01a6, 0x017c, 0x03cf, 0x0400 },
		{ 0x00a2, 0x012e, 0x015f, 0x0246, 0x021c, 0x01f2, 0x01c8, 0x0476 },
		{ 0x00bd, 0x00ee, 0x01d5, 0x0150, 0x0292, 0x0268, 0x023e, 0x0214 }
	};
	
	short data[8][8];
	
	dct(pixels, data);
	
	for (int row = 0; row < 8; row++)
	{
		for (int col = 0; col < 8; col++)
			printf("0x%08x ", data[row][col]);

		printf("\n");
	}
		
	// CHECK: 0x00000d27 0xfffff97a 0xfffffff9 0xffffff15 0x00000021 0xffffffb3 0x0000000e 0x00000007 
	// CHECK: 0xfffffdde 0x0000006b 0xffffff86 0x0000007a 0xffffffa1 0x00000033 0xffffffde 0xffffffe0 
	// CHECK: 0xfffffeaf 0x000001a6 0xffffff3b 0xffffffce 0x00000063 0xffffffae 0x00000023 0x0000002b 
	// CHECK: 0xffffffca 0xffffff9c 0x0000011f 0xffffff13 0x00000003 0x0000007b 0xffffffbc 0xffffffaf 
	// CHECK: 0xffffffb0 0x0000004a 0xffffffc8 0x000000e1 0xfffffee3 0xffffffd3 0x00000085 0x0000006f 
	// CHECK: 0xffffffff 0xffffffe8 0x00000019 0xffffffc3 0x000000e3 0xffffff4a 0xffffffe1 0xffffffd2 
	// CHECK: 0xffffffba 0xfffffff6 0x0000000c 0x00000055 0xffffffe3 0x00000079 0xffffff2b 0x00000034 
	// CHECK: 0x00000040 0x00000039 0x00000006 0xffffffc2 0xffffffe7 0xffffffd0 0x0000004c 0xffffff14

	return 0;
}

