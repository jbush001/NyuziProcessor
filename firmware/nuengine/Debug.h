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

	Debug &operator<<(const void *str)
	{
		*this << (unsigned int) str;
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
	
	// Printing floating point numbers accurately is a tricky problem.
	// This implementation is simple and buggy.
	// See "How to Print Floating Point Numbers Accurately" by Guy L. Steele Jr.
	// and Jon L. White for the gory details.
	Debug &operator<<(float f)
	{
		// XXX does not handle inf and NaN

		if (f < 0.0f)
		{
			*this << "-";
			f = -f;
		}
	
		int wholePart = (int) f;
		float frac = f - wholePart;
		
		// Print the whole part
		if (wholePart == 0)
			*this << "0";
		else
		{
			char wholeStr[20];
			int wholeOffs = 19;
			while (wholePart > 0)
			{
				int digit = wholePart % 10;
				wholeStr[wholeOffs--] = digit + '0';
				wholePart /= 10;
			}

			while (wholeOffs < 20)
				*this << wholeStr[wholeOffs++];
		}
		
		*this << '.';

		// Print the fractional part, not especially accurately
		int maxDigits = 7;
		do
		{
			frac = frac * 10;	
			int digit = (int) frac;
			frac -= digit;
			*this << (char) (digit + '0');
		}
		while (frac > 0.0f && maxDigits-- > 0);
		
		return *this;
	}
	
private:
	void writeChar(char c)
	{
		*((volatile unsigned int*) 0xFFFF0004) = c;
	}
};

#endif
