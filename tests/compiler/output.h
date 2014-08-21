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
