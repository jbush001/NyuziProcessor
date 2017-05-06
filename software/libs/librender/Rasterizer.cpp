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

//
// The basic approach is based on this article:
// http://www.drdobbs.com/parallel/rasterization-on-larrabee/217200602
// And is also described in "Hierarchical polygon tiling with coverage
// masks" Proceedings of ACM SIGGRAPH 93, Ned Greene.
//

#include "Rasterizer.h"
#include "SIMDMath.h"

namespace librender
{

namespace
{

const int kMaxSweep = 0;
const veci16_t kXStep = { 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };
const veci16_t kYStep = { 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 };

void setupRecurseEdge(int tileLeft, int tileTop, int x1, int y1,
                      int x2, int y2, int &outAcceptEdgeValue, int &outRejectEdgeValue,
                      veci16_t &outAcceptStepMatrix, veci16_t &outRejectStepMatrix)
{
    veci16_t xAcceptStepValues = kXStep * (kTileSize / 4);
    veci16_t yAcceptStepValues = kYStep * (kTileSize / 4);
    veci16_t xRejectStepValues = xAcceptStepValues;
    veci16_t yRejectStepValues = yAcceptStepValues;
    int trivialAcceptX = tileLeft;
    int trivialAcceptY = tileTop;
    int trivialRejectX = tileLeft;
    int trivialRejectY = tileTop;
    const int kThreeQuarterTile = kTileSize * 3 / 4;

    if (y2 > y1)
    {
        trivialAcceptX += kTileSize - 1;
        xAcceptStepValues = xAcceptStepValues - kThreeQuarterTile;
    }
    else
    {
        trivialRejectX += kTileSize - 1;
        xRejectStepValues = xRejectStepValues - kThreeQuarterTile;
    }

    if (x2 > x1)
    {
        trivialRejectY += kTileSize - 1;
        yRejectStepValues = yRejectStepValues - kThreeQuarterTile;
    }
    else
    {
        trivialAcceptY += kTileSize - 1;
        yAcceptStepValues = yAcceptStepValues - kThreeQuarterTile;
    }

    int xStep = y2 - y1;
    int yStep = x2 - x1;

    outAcceptEdgeValue = (trivialAcceptX - x1) * xStep - (trivialAcceptY - y1) * yStep;
    outRejectEdgeValue = (trivialRejectX - x1) * xStep - (trivialRejectY - y1) * yStep;

    if (y1 > y2 || (y1 == y2 && x2 > x1))
    {
        // This is a top or left edge.  We adjust the edge equation values by one
        // so it doesn't overlap (top left fill convention).
        outAcceptEdgeValue++;
        outRejectEdgeValue++;
    }

    // Set up xStepValues
    xAcceptStepValues *= xStep;
    xRejectStepValues *= xStep;

    // Set up yStepValues
    yAcceptStepValues *= yStep;
    yRejectStepValues *= yStep;

    // Add together
    outAcceptStepMatrix = xAcceptStepValues - yAcceptStepValues;
    outRejectStepMatrix = xRejectStepValues - yRejectStepValues;
}

// Workhorse of recursive rasterization.  Subdivides tile into 4x4 grids.
void subdivideTile(
    TriangleFiller &filler,
    const int acceptCornerValue1,
    const int acceptCornerValue2,
    const int acceptCornerValue3,
    const int rejectCornerValue1,
    const int rejectCornerValue2,
    const int rejectCornerValue3,
    const veci16_t acceptStep1,
    const veci16_t acceptStep2,
    const veci16_t acceptStep3,
    const veci16_t rejectStep1,
    const veci16_t rejectStep2,
    const veci16_t rejectStep3,
    const int tileSizeBits,	// log2 tile size (1 << tileSizeBits = pixels)
    const int tileLeft,
    const int tileTop,
    const int clipRight,
    const int clipBottom)
{
    // Compute accept masks
    const veci16_t acceptEdgeValue1 = acceptStep1 + acceptCornerValue1;
    const veci16_t acceptEdgeValue2 = acceptStep2 + acceptCornerValue2;
    const veci16_t acceptEdgeValue3 = acceptStep3 + acceptCornerValue3;
    const vmask_t trivialAcceptMask =
            __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue1, veci16_t(0))
            & __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue2, veci16_t(0))
            & __builtin_nyuzi_mask_cmpi_sle(acceptEdgeValue3, veci16_t(0));

    if (tileSizeBits == 2)
    {
        // End recursion
        if (trivialAcceptMask)
            filler.fillMasked(tileLeft, tileTop, trivialAcceptMask);

        return;
    }

    const int subTileSizeBits = tileSizeBits - 2;

    // Process all trivially accepted blocks
    if (trivialAcceptMask != 0)
    {
        unsigned int currentMask = trivialAcceptMask;

        while (currentMask)
        {
            const int index = __builtin_ctz(currentMask);
            currentMask &= ~(1 << index);
            const int subTileLeft = tileLeft + ((index & 3) << subTileSizeBits);
            const int subTileTop = tileTop + ((index >> 2) << subTileSizeBits);
            const int tileCount = 1 << subTileSizeBits;
            const int hcount = min(tileCount, clipRight - subTileLeft);
            const int vcount = min(tileCount, clipBottom - subTileTop);
            for (int y = 0; y < vcount; y += 4)
            {
                for (int x = 0; x < hcount; x += 4)
                    filler.fillMasked(subTileLeft + x, subTileTop + y, 0xffff);
            }
        }
    }

    // Compute reject masks
    const veci16_t rejectEdgeValue1 = rejectStep1 + rejectCornerValue1;
    const veci16_t rejectEdgeValue2 = rejectStep2 + rejectCornerValue2;
    const veci16_t rejectEdgeValue3 = rejectStep3 + rejectCornerValue3;
    const vmask_t trivialRejectMask =
            __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue1, veci16_t(0))
            | __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue2, veci16_t(0))
            | __builtin_nyuzi_mask_cmpi_sgt(rejectEdgeValue3, veci16_t(0));

    // Recurse into blocks that are neither trivially rejected or accepted.
    // They are partially overlapped and need to be further subdivided.
    unsigned int recurseMask = (trivialAcceptMask | trivialRejectMask) ^ 0xffff;
    if (recurseMask)
    {
        // Divide each step matrix by 4
        const veci16_t subAcceptStep1 = acceptStep1 >> 2;
        const veci16_t subAcceptStep2 = acceptStep2 >> 2;
        const veci16_t subAcceptStep3 = acceptStep3 >> 2;
        const veci16_t subRejectStep1 = rejectStep1 >> 2;
        const veci16_t subRejectStep2 = rejectStep2 >> 2;
        const veci16_t subRejectStep3 = rejectStep3 >> 2;

        while (recurseMask)
        {
            const int index = __builtin_ctz(recurseMask);
            recurseMask &= ~(1 << index);
            const int x = tileLeft + ((index & 3) << subTileSizeBits);
            const int y = tileTop + ((index >> 2) << subTileSizeBits);
            if (x >= clipRight || y >= clipBottom)
                continue;	// Clip tiles that are outside viewport

            subdivideTile(
                filler,
                acceptEdgeValue1[index],
                acceptEdgeValue2[index],
                acceptEdgeValue3[index],
                rejectEdgeValue1[index],
                rejectEdgeValue2[index],
                rejectEdgeValue3[index],
                subAcceptStep1,
                subAcceptStep2,
                subAcceptStep3,
                subRejectStep1,
                subRejectStep2,
                subRejectStep3,
                subTileSizeBits,
                x,
                y,
                clipRight,
                clipBottom);
        }
    }
}

void rasterizeRecursive(TriangleFiller &filler,
                        int tileLeft, int tileTop, int clipRight, int clipBottom,
                        int x1, int y1, int x2, int y2, int x3, int y3)
{
    int acceptValue1;
    int rejectValue1;
    veci16_t acceptStepMatrix1;
    veci16_t rejectStepMatrix1;
    int acceptValue2;
    int rejectValue2;
    veci16_t acceptStepMatrix2;
    veci16_t rejectStepMatrix2;
    int acceptValue3;
    int rejectValue3;
    veci16_t acceptStepMatrix3;
    veci16_t rejectStepMatrix3;

    // This assumes counter-clockwise winding for triangles that are
    // facing the camera.
    setupRecurseEdge(tileLeft, tileTop, x1, y1, x3, y3, acceptValue1, rejectValue1,
                     acceptStepMatrix1, rejectStepMatrix1);
    setupRecurseEdge(tileLeft, tileTop, x3, y3, x2, y2, acceptValue2, rejectValue2,
                     acceptStepMatrix2, rejectStepMatrix2);
    setupRecurseEdge(tileLeft, tileTop, x2, y2, x1, y1, acceptValue3, rejectValue3,
                     acceptStepMatrix3, rejectStepMatrix3);

    subdivideTile(
        filler,
        acceptValue1,
        acceptValue2,
        acceptValue3,
        rejectValue1,
        rejectValue2,
        rejectValue3,
        acceptStepMatrix1,
        acceptStepMatrix2,
        acceptStepMatrix3,
        rejectStepMatrix1,
        rejectStepMatrix2,
        rejectStepMatrix3,
        __builtin_ctz(kTileSize),
        tileLeft,
        tileTop,
        clipRight,
        clipBottom);
}

inline int min3(int a, int b, int c)
{
    int value = a < b ? a : b;
    return c < value ? c : value;
}

inline int max3(int a, int b, int c)
{
    int value = a > b ? a : b;
    return c > value ? c : value;
}

inline void setupSweepEdge(int left, int top, int x1, int y1, int x2, int y2,
                           int &outXStep4, int &outYStep4, veci16_t &outEdgeValue)
{
    int xStep1 = y2 - y1;
    int yStep1 = x2 - x1;
    outEdgeValue = (kXStep + left - x2) * xStep1
                   - (kYStep + top - y2) * yStep1;
    if (y1 > y2 || (y1 == y2 && x2 > x1))
        outEdgeValue -= 1;	// Left or top edge

    outXStep4 = xStep1 * 4;
    outYStep4 = yStep1 * 4;
}

//
// For smaller triangles, this skips the setup overhead of the recursive rasterizer.
// It instead steps the 4x4 grid over the bounding box of the triangle in a serpentine
// pattern.
// Currently disabled.
//
void rasterizeSweep(TriangleFiller &filler,
                    int bbLeft, int bbTop, int bbRight, int bbBottom,
                    int x1, int y1, int x2, int y2, int x3, int y3)
{
    int xStep4_1;
    int yStep4_1;
    int xStep4_2;
    int yStep4_2;
    int xStep4_3;
    int yStep4_3;
    veci16_t edgeValue1;
    veci16_t edgeValue2;
    veci16_t edgeValue3;

    setupSweepEdge(bbLeft, bbTop, x1, y1, x2, y2, xStep4_1, yStep4_1, edgeValue1);
    setupSweepEdge(bbLeft, bbTop, x2, y2, x3, y3, xStep4_2, yStep4_2, edgeValue2);
    setupSweepEdge(bbLeft, bbTop, x3, y3, x1, y1, xStep4_3, yStep4_3, edgeValue3);

    int col = bbLeft;
    int row = bbTop;
    int stepDir = 4;
    int numCols = (bbRight - bbLeft) / 4;
    do
    {
        for (int colCount = 0; ; colCount++)
        {
            vmask_t mask = __builtin_nyuzi_mask_cmpi_sge(edgeValue1, veci16_t(0))
                       & __builtin_nyuzi_mask_cmpi_sge(edgeValue2, veci16_t(0))
                       & __builtin_nyuzi_mask_cmpi_sge(edgeValue3, veci16_t(0));
            if (mask)
                filler.fillMasked(col, row, mask);

            if (colCount == numCols)
                break;

            // Step left/right
            edgeValue1 += xStep4_1;
            edgeValue2 += xStep4_2;
            edgeValue3 += xStep4_3;
            col += stepDir;
        }

        // Change direction, step down
        xStep4_1 = -xStep4_1;
        xStep4_2 = -xStep4_2;
        xStep4_3 = -xStep4_3;
        stepDir = -stepDir;
        edgeValue1 -= yStep4_1;
        edgeValue2 -= yStep4_2;
        edgeValue3 -= yStep4_3;
        row += 4;
    }
    while (row < bbBottom);
}

} // namespace

void fillTriangle(TriangleFiller &filler,
                  int tileLeft, int tileTop,
                  int x1, int y1, int x2, int y2, int x3, int y3,
                  int clipRight, int clipBottom)
{
    int bbLeft = max(min3(x1, x2, x3) & ~3, tileLeft);
    int bbTop = max(min3(y1, y2, y3) & ~3, tileTop);
    int bbRight = min3((max3(x1, x2, x3) + 3) & ~3, clipRight, tileLeft + kTileSize);
    int bbBottom = min3((max3(y1, y2, y3) + 3) & ~3, clipBottom, tileTop + kTileSize);

    if (bbRight - bbLeft < kMaxSweep && bbBottom - bbTop < kMaxSweep)
        rasterizeSweep(filler, bbLeft, bbTop, bbRight, bbBottom, x1, y1, x2, y2, x3, y3);
    else
    {
        rasterizeRecursive(filler, tileLeft, tileTop, clipRight, clipBottom,
                           x1, y1, x2, y2, x3, y3);
    }
}

} // namespace librender