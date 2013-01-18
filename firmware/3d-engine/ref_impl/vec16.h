// 
// Copyright 2011-2012 Jeff Bush
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

//
// Simulates a 16 element vector register
//

#ifndef __VEC16_H
#define __VEC16_H

#include <string.h>
#include <iostream>

template <typename T>
class vec16
{
public:
	vec16();
	vec16 &operator=(const vec16&);
	vec16 operator*(T) const;
	vec16 operator*(const vec16&) const;
	vec16 operator/(T) const;
	vec16 operator/(const vec16&) const;
	vec16 operator>>(T) const;
	vec16 operator+(const vec16&) const;
	vec16 operator+(T) const;
	vec16 operator-(const vec16&) const;
	vec16 operator-(T) const;
	int operator>=(T) const;
	int operator<=(T) const;
	vec16<T> reciprocal() const;
	void load(const T values[]);
	T operator[](int index) const;
	void print() const;
	
private:
	T fValues[16];
};

template <typename T>
vec16<T>::vec16()
{
	memset(fValues, 0, sizeof(fValues));
}

template <typename T>
vec16<T> &vec16<T>::operator=(const vec16 &src)
{
	memcpy(fValues, src.fValues, sizeof(fValues));
}

template <typename T>
vec16<T> vec16<T>::operator*(T multiplier) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] * multiplier;

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator*(const vec16 &multiplier) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] * multiplier[i];

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator/(T dividend) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] / dividend;

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator/(const vec16 &dividend) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] / dividend[i];

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator>>(T shamt) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] >> shamt;

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator+(const vec16 &add) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] + add.fValues[i];

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator+(T add) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] + add;

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator-(const vec16 &sub) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] - sub.fValues[i];

	return result;
}

template <typename T>
vec16<T> vec16<T>::operator-(T sub) const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] - sub;

	return result;
}

template <typename T>
vec16<T> vec16<T>::reciprocal() const
{
	vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = 1.0 / fValues[i];

	return result;
}

template <typename T>
int vec16<T>::operator>=(T cmpval) const
{
	int mask = 0;

	for (int i = 0; i < 16; i++)
		mask |= fValues[i] >= cmpval ? (1 << i) : 0;

	return mask;
}

template <typename T>
int vec16<T>::operator<=(T cmpval) const
{
	int mask = 0;

	for (int i = 0; i < 16; i++)
		mask |= fValues[i] <= cmpval ? (1 << i) : 0;

	return mask;
}

template <typename T>
void vec16<T>::load(const T values[])
{
	for (int i = 0; i < 16; i++)
		fValues[15 - i] = values[i];
}

template <typename T>
T vec16<T>::operator[](int index) const
{
	return fValues[index];
}

template <typename T>
void vec16<T>::print() const
{
	for (int i = 15; i >= 0; i--)
		std::cout << fValues[i] << " ";

	std::cout << std::endl;
}



#endif
