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
#include <stdio.h>
#include <string.h>
#include "SIMDMath.h"
#include "Vec3.h"

namespace librender
{

//
// This is a convenience class used by shaders.
//

class Matrix
{
public:
    Matrix()
    {
        // Identity matrix
        memset(fValues, 0, sizeof(float) * 16);
        fValues[0][0] = 1.0f;
        fValues[1][1] = 1.0f;
        fValues[2][2] = 1.0f;
        fValues[3][3] = 1.0f;
    }

    explicit Matrix(const float values[4][4])
    {
        for (int row = 0; row < 4; row++)
        {
            for (int col = 0; col < 4; col++)
                fValues[row][col] = values[row][col];
        }
    }

    Matrix(const Matrix &rhs) = default;
    Matrix &operator=(const Matrix &rhs) = default;

    Matrix operator*(const Matrix &rhs) const
    {
        Matrix newMat;

        for (int col = 0; col < 4; col++)
        {
            for (int row = 0; row < 4; row++)
            {
                float sum = 0.0f;
                for (int i = 0; i < 4; i++)
                    sum += fValues[row][i] * rhs.fValues[i][col];

                newMat.fValues[row][col] = sum;
            }
        }

        return newMat;
    }

    Matrix &operator*=(const Matrix &rhs)
    {
        *this = *this * rhs;
        return *this;
    }

    Vec3 operator*(const Vec3 &rhs) const
    {
        float result[3];
        for (int row = 0; row < 3; row++)
        {
            float sum = 0.0f;
            for (int col = 0; col < 3; col++)
                sum += fValues[row][col] * rhs[col];

            // Assume last row of vector is 1
            sum += fValues[row][3];
            result[row] = sum;
        }

        return Vec3(result[0], result[1], result[2]);
    }

    // Multiply 16 Vec3s by this matrix.
    void mulVec(vecf16_t *outVec, const vecf16_t *inVec) const
    {
        for (int row = 0; row < 4; row++)
        {
            vecf16_t sum = 0.0f;
            for (int col = 0; col < 4; col++)
                sum += fValues[row][col] * inVec[col];

            outVec[row] = sum;
        }
    }

    Matrix upper3x3() const
    {
        Matrix newMat = *this;
        newMat.fValues[0][3] = 0.0f;
        newMat.fValues[1][3] = 0.0f;
        newMat.fValues[2][3] = 0.0f;
        newMat.fValues[3][0] = 0.0f;
        newMat.fValues[3][1] = 0.0f;
        newMat.fValues[3][2] = 0.0f;

        return newMat;
    }

    Matrix inverse() const
    {
        float newVals[4][4];

        float s0 = fValues[0][0] * fValues[1][1] - fValues[1][0] * fValues[0][1];
        float s1 = fValues[0][0] * fValues[1][2] - fValues[1][0] * fValues[0][2];
        float s2 = fValues[0][0] * fValues[1][3] - fValues[1][0] * fValues[0][3];
        float s3 = fValues[0][1] * fValues[1][2] - fValues[1][1] * fValues[0][2];
        float s4 = fValues[0][1] * fValues[1][3] - fValues[1][1] * fValues[0][3];
        float s5 = fValues[0][2] * fValues[1][3] - fValues[1][2] * fValues[0][3];

        float c5 = fValues[2][2] * fValues[3][3] - fValues[3][2] * fValues[2][3];
        float c4 = fValues[2][1] * fValues[3][3] - fValues[3][1] * fValues[2][3];
        float c3 = fValues[2][1] * fValues[3][2] - fValues[3][1] * fValues[2][2];
        float c2 = fValues[2][0] * fValues[3][3] - fValues[3][0] * fValues[2][3];
        float c1 = fValues[2][0] * fValues[3][2] - fValues[3][0] * fValues[2][2];
        float c0 = fValues[2][0] * fValues[3][1] - fValues[3][0] * fValues[2][1];

        float invdet = 1.0f / (s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0);

        newVals[0][0] = (fValues[1][1] * c5 - fValues[1][2] * c4 + fValues[1][3] * c3) * invdet;
        newVals[0][1] = (-fValues[0][1] * c5 + fValues[0][2] * c4 - fValues[0][3] * c3) * invdet;
        newVals[0][2] = (fValues[3][1] * s5 - fValues[3][2] * s4 + fValues[3][3] * s3) * invdet;
        newVals[0][3] = (-fValues[2][1] * s5 + fValues[2][2] * s4 - fValues[2][3] * s3) * invdet;

        newVals[1][0] = (-fValues[1][0] * c5 + fValues[1][2] * c2 - fValues[1][3] * c1) * invdet;
        newVals[1][1] = (fValues[0][0] * c5 - fValues[0][2] * c2 + fValues[0][3] * c1) * invdet;
        newVals[1][2] = (-fValues[3][0] * s5 + fValues[3][2] * s2 - fValues[3][3] * s1) * invdet;
        newVals[1][3] = (fValues[2][0] * s5 - fValues[2][2] * s2 + fValues[2][3] * s1) * invdet;

        newVals[2][0] = (fValues[1][0] * c4 - fValues[1][1] * c2 + fValues[1][3] * c0) * invdet;
        newVals[2][1] = (-fValues[0][0] * c4 + fValues[0][1] * c2 - fValues[0][3] * c0) * invdet;
        newVals[2][2] = (fValues[3][0] * s4 - fValues[3][1] * s2 + fValues[3][3] * s0) * invdet;
        newVals[2][3] = (-fValues[2][0] * s4 + fValues[2][1] * s2 - fValues[2][3] * s0) * invdet;

        newVals[3][0] = (-fValues[1][0] * c3 + fValues[1][1] * c1 - fValues[1][2] * c0) * invdet;
        newVals[3][1] = (fValues[0][0] * c3 - fValues[0][1] * c1 + fValues[0][2] * c0) * invdet;
        newVals[3][2] = (-fValues[3][0] * s3 + fValues[3][1] * s1 - fValues[3][2] * s0) * invdet;
        newVals[3][3] = (fValues[2][0] * s3 - fValues[2][1] * s1 + fValues[2][2] * s0) * invdet;

        return Matrix(newVals);
    }

    Matrix transpose() const
    {
        float newVals[4][4];
        for (int row = 0; row < 4; row++)
        {
            for (int col = 0; col < 4; col++)
                newVals[row][col] = fValues[col][row];
        }

        return Matrix(newVals);
    }

    void print() const
    {
        for (int row = 0; row < 4; row++)
        {
            for (int col = 0; col < 4; col++)
                printf("%g ", fValues[row][col]);

            printf("\n");
        }
    }

    // Rotate about an axis (which is expected to be unit length)
    static Matrix getRotationMatrix(float angle, const Vec3 &around)
    {
        float s = sin(angle);
        float c = cos(angle);
        float t = 1.0f - c;
        Vec3 a = around.normalized();

        const float kMat1[4][4] =
        {
            { (t * a[0] * a[0] + c), (t * a[0] * a[1] - s * a[2]), (t * a[0] * a[1] + s * a[1]), 0.0f },
            { (t * a[0] * a[1] + s * a[2]), (t * a[1] * a[1] + c), (t * a[0] * a[2] - s * a[0]), 0.0f },
            { (t * a[0] * a[1] - s * a[1]), (t * a[1] * a[2] + s * a[0]), (t * a[2] * a[2] + c), 0.0f },
            { 0.0f, 0.0f, 0.0f, 1.0f }
        };

        return Matrix(kMat1);
    }

    static Matrix getTranslationMatrix(const Vec3 &trans)
    {
        const float kValues[4][4] =
        {
            { 1.0f, 0.0f, 0.0f, trans[0] },
            { 0.0f, 1.0f, 0.0f, trans[1] },
            { 0.0f, 0.0f, 1.0f, trans[2] },
            { 0.0f, 0.0f, 0.0f, 1.0f },
        };

        return Matrix(kValues);
    }

    static Matrix getProjectionMatrix(float viewPortWidth, float viewPortHeight)
    {
        const float kAspectRatio = viewPortWidth / viewPortHeight;
        const float kProjCoeff[4][4] =
        {
            { 1.0f / kAspectRatio, 0.0, 0.0, 0.0 },
            { 0.0, 1.0, 0.0, 0.0 },
            { 0.0, 0.0, 1.0, 0 },
            { 0.0, 0.0, -1.0, 0.0 },
        };

        return Matrix(kProjCoeff);
    }

    static Matrix getScaleMatrix(float scale)
    {
        const float kValues[4][4] =
        {
            { scale, 0.0f, 0.0f, 0.0f },
            { 0.0f, scale, 0.0f, 0.0f },
            { 0.0f, 0.0f, scale, 0.0f },
            { 0.0f, 0.0f, 0.0f, 1.0f },
        };

        return Matrix(kValues);
    }

    static Matrix lookAt(const Vec3 &location, const Vec3 &lookAt, const Vec3 &up)
    {
        Vec3 z = (lookAt - location).normalized();
        Vec3 x = z.crossProduct(up).normalized();
        Vec3 y = x.crossProduct(z).normalized();

        const float rotationMatrix[4][4] =
        {
            { x[0], x[1], x[2], 0 },
            { y[0], y[1], y[2], 0 },
            { -z[0], -z[1], -z[2], 0 },
            { 0, 0, 0, 1 }
        };

        return Matrix(rotationMatrix) * getTranslationMatrix(-location);
    }

private:
    float fValues[4][4];
};

} // namespace librender
