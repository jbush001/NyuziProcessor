//
// Copyright 2011-2015 Jeff Bush
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


#pragma once

#include <math.h>

namespace librender
{

//
// 3 element vector
//
class Vec3
{
public:
    Vec3()
    {
        fValues[0] = 0.0f;
        fValues[1] = 0.0f;
        fValues[2] = 0.0f;
    }

    Vec3(float a, float b, float c)
    {
        fValues[0] = a;
        fValues[1] = b;
        fValues[2] = c;
    }

    Vec3(const Vec3 &rhs) = default;
    Vec3 &operator=(const Vec3 &rhs) = default;

    Vec3 operator+(const Vec3 &other) const
    {
        Vec3 newVal;
        for (int i = 0; i < 3; i++)
            newVal.fValues[i] = fValues[i] + other.fValues[i];

        return newVal;
    }

    Vec3 operator-(const Vec3 &other) const
    {
        Vec3 newVal;
        for (int i = 0; i < 3; i++)
            newVal.fValues[i] = fValues[i] - other.fValues[i];

        return newVal;
    }

    Vec3 operator*(float other) const
    {
        Vec3 newVal;
        for (int i = 0; i < 3; i++)
            newVal.fValues[i] = fValues[i] * other;

        return newVal;
    }

    Vec3 &operator+=(const Vec3 &other)
    {
        *this = *this + other;
        return *this;
    }

    Vec3 operator/(float other) const
    {
        Vec3 newVal;
        float denom = 1.0 / other;
        for (int i = 0; i < 3; i++)
            newVal.fValues[i] = fValues[i] * denom;

        return newVal;
    }

    float magnitude() const
    {
        float magSquared = 0.0;
        for (int i = 0; i < 3; i++)
            magSquared += fValues[i] * fValues[i];

        return sqrt(magSquared);
    }

    Vec3 normalized() const
    {
        return *this / magnitude();
    }

    float &operator[](int index)
    {
        return fValues[index];
    }

    float operator[](int index) const
    {
        return fValues[index];
    }

    Vec3 crossProduct(const Vec3 &other) const
    {
        Vec3 result;
        result.fValues[0] = fValues[1] * other.fValues[2] - fValues[2] * other.fValues[1];
        result.fValues[1] = fValues[2] * other.fValues[0] - fValues[0] * other.fValues[2];
        result.fValues[2] = fValues[0] * other.fValues[1] - fValues[1] * other.fValues[0];
        return result;
    }

    Vec3 operator-() const
    {
        return Vec3(-fValues[0], -fValues[1], -fValues[2]);
    }

    void print() const
    {
        printf("%f %f %f\n", fValues[0], fValues[1], fValues[2]);
    }

private:
    float fValues[3];
};

} // namespace librender
