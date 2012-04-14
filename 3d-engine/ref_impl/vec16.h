//
// Simulates a 16 element vector register
//

#ifndef __VEC16_H
#define __VEC16_H

#include <string.h>
#include <stdio.h>

template <typename T>
class Vec16
{
public:
	Vec16();
	Vec16 &operator=(const Vec16&);
	Vec16 operator*(T) const;
	Vec16 operator>>(T) const;
	Vec16 operator+(const Vec16&) const;
	Vec16 operator+(T) const;
	Vec16 operator-(const Vec16&) const;
	Vec16 operator-(T) const;
	int operator>=(T) const;
	int operator<=(T) const;
	void load(const T values[]);
	T operator[](int index) const;
	void print() const;
	
private:
	T fValues[16];
};

template <typename T>
Vec16<T>::Vec16()
{
	memset(fValues, 0, sizeof(fValues));
}

template <typename T>
Vec16<T> &Vec16<T>::operator=(const Vec16 &src)
{
	memcpy(fValues, src.fValues, sizeof(fValues));
}

template <typename T>
Vec16<T> Vec16<T>::operator*(T multiplier) const
{
	Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] * multiplier;

	return result;
}

template <typename T>
Vec16<T> Vec16<T>::operator>>(T shamt) const
{
	Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] >> shamt;

	return result;
}

template <typename T>
Vec16<T> Vec16<T>::operator+(const Vec16 &add) const
{
	Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] + add.fValues[i];

	return result;
}

template <typename T>
Vec16<T> Vec16<T>::operator+(T add) const
{
	Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] + add;

	return result;
}

template <typename T>
Vec16<T> Vec16<T>::operator-(const Vec16 &sub) const
{
	Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] - sub.fValues[i];

	return result;
}

template <typename T>
Vec16<T> Vec16<T>::operator-(T sub) const
{
	Vec16 result;
	for (int i = 0; i < 16; i++)
		result.fValues[i] = fValues[i] - sub;

	return result;
}

template <typename T>
int Vec16<T>::operator>=(T cmpval) const
{
	int mask = 0;

	for (int i = 0; i < 16; i++)
		mask |= fValues[i] >= cmpval ? (1 << i) : 0;

	return mask;
}

template <typename T>
int Vec16<T>::operator<=(T cmpval) const
{
	int mask = 0;

	for (int i = 0; i < 16; i++)
		mask |= fValues[i] <= cmpval ? (1 << i) : 0;

	return mask;
}

template <typename T>
void Vec16<T>::load(const T values[])
{
	for (int i = 0; i < 16; i++)
		fValues[15 - i] = values[i];
}

template <typename T>
T Vec16<T>::operator[](int index) const
{
	return fValues[index];
}

template <typename T>
void Vec16<T>::print() const
{
	for (int i = 15; i >= 0; i--)
		printf("%08x ", fValues[i]);
}



#endif
