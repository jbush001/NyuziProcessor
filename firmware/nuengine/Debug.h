// 
// Copyright 2013 Jeff Bush
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

#ifndef __DEBUG_H
#define __DEBUG_H

class Debug
{
public:
	static Debug debug;

	Debug &operator<<(const char *str)
	{
		for (const char *c = str; *c; c++)
			writeChar(*c);
			
		return *this;
	}

	Debug &operator<<(int value)
	{
		return *this << (unsigned int) value;
	}

	Debug &operator<<(unsigned int value)
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
	
	Debug &operator<<(int value __attribute__((__vector_size__(64))))
	{
		for (int i = 0; i < 16; i++)
			*this << value[i] << ' ';

		return *this;
	}

	Debug &operator<<(float value __attribute__((__vector_size__(64))))
	{
		for (int i = 0; i < 16; i++)
			*this << value[i] << ' ';

		return *this;
	}
	
	Debug &operator<<(char c)
	{
		writeChar(c);
		return *this;
	}
	
	Debug &operator<<(float f)
	{
		*this << *((int*) &f);
	
#if 0
		float wholePart = (int) f;
		float frac = f - wholePart;
		
		// Print the whole part
		char wholeStr[20];
		int wholeOffs = 19;
		while (wholePart > 1)
		{
			float rounded = (float)(((int)(wholePart / 10.0f)) * 10);
			int digit = wholePart - rounded;
			wholeStr[wholeOffs--] = digit + '0';
			wholePart /= 10.0f;
		}

		while (wholeOffs < 20)
			*this << wholeStr[wholeOffs++];
		
		*this << '.';

		// Print the fractional part
		do
		{
			frac = frac * 10;	
			int wp = (int) frac;
			frac -= wp;
			int digit = wp + '0';
			*this << (char) digit;
		}
		while (frac > 0.0f);
#endif
		
		return *this;
	}
	
private:
	void writeChar(char c)
	{
		*((volatile unsigned int*) 0xFFFF0004) = c;
	}
};

#endif
