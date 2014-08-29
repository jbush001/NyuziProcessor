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

#ifndef __OUTPUT_H
#define __OUTPUT_H

//
// Common test code used to print results for checking
//

class Output
{
public:
	Output &operator<<(const char *str)
	{
		for (const char *c = str; *c; c++)
			writeChar(*c);
			
		return *this;
	}

	Output &operator<<(int value)
	{
		return *this << (unsigned int) value;
	}

	Output &operator<<(unsigned int value)
	{
		writeChar('0');
		writeChar('x');
		for (int i = 0; i < 8; i++)
		{
			int digitValue = value >> 28;
			value <<= 4;
			if (digitValue < 10)
				writeChar(digitValue + '0');
			else 
				writeChar(digitValue - 10 + 'a');
		}
		
		return *this;
	}
	
	Output &operator<<(int value __attribute__((__vector_size__(16 * sizeof(int)))))
	{
		for (int i = 0; i < 16; i++)
			*this << value[i] << ' ';

		return *this;
	}
	
	Output &operator<<(char c)
	{
		writeChar(c);
		return *this;
	}
	
private:
	void writeChar(char c)
	{
		*((volatile unsigned int*) 0xFFFF0000) = c;
	}
};

#endif
