#ifndef __RENDER_TARGET_H
#define __RENDER_TARGET_H

#include "Debug.h"
#include "vectypes.h"

class RenderTarget
{
public:
	RenderTarget(int fbBase, int fbWidth, int fbHeight)
		:	fWidth(fbWidth),
			fHeight(fbHeight),
			fStride(fbWidth * 4)
	{
		f4x4AtOrigin[0] = fbBase;
		f4x4AtOrigin[1] = fbBase + 4;
		f4x4AtOrigin[2] = fbBase + 8; 
		f4x4AtOrigin[3] = fbBase + 12;
		f4x4AtOrigin[4] = fbBase + (fbWidth * 4);
		f4x4AtOrigin[5] = fbBase + (fbWidth * 4) + 4;
		f4x4AtOrigin[6] = fbBase + (fbWidth * 4) + 8; 
		f4x4AtOrigin[7] = fbBase + (fbWidth * 4) + 12;
		f4x4AtOrigin[8] = fbBase + (fbWidth * 8);
		f4x4AtOrigin[9] = fbBase + (fbWidth * 8) + 4;
		f4x4AtOrigin[10] = fbBase + (fbWidth * 8) + 8; 
		f4x4AtOrigin[11] = fbBase + (fbWidth * 8) + 12;
		f4x4AtOrigin[12] = fbBase + (fbWidth * 12);
		f4x4AtOrigin[13] = fbBase + (fbWidth * 12) + 4;
		f4x4AtOrigin[14] = fbBase + (fbWidth * 12) + 8; 
		f4x4AtOrigin[15] = fbBase + (fbWidth * 12) + 12;
	}

	void fillMasked(int left, int top, int mask, veci16 colors)
	{
		veci16 ptrs = f4x4AtOrigin + __builtin_vp_makevectori(left * 4 + top * fStride);
		__builtin_vp_scatter_storei_masked(ptrs, colors, mask);
	}
	
	inline int getWidth() const 
	{
		return fWidth;
	}
	
	inline int getHeight() const
	{
		return fHeight;
	}

private:
	veci16 f4x4AtOrigin;
	int fWidth;
	int fHeight;
	int fStride;
};

#endif
