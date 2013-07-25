
typedef float vec16f __attribute__((__vector_size__(16 * sizeof(int))));
typedef int vec16i __attribute__((__vector_size__(16 * sizeof(int))));

#define PI 3.141579

vec16f fmodv(vec16f val1, vec16f val2)
{
	vec16f multiple = __builtin_vp_vitof(__builtin_vp_vftoi(val1 / val2));
	return val1 - (multiple * val2);
}

//
// Use taylor series to approximate sine
//   x**3/3! + x**5/5! - x**7/7! ...
//

#define NUM_TERMS 6

float denominators[] = { 
	0.166666666666667f, 	// 1 / 3!
	0.008333333333333f,		// 1 / 5!
	0.000198412698413f,		// 1 / 7!
	0.000002755731922f,		// 1 / 9!
	2.50521084e-8f,			// 1 / 11!
	1.6059044e-10f			// 1 / 13!
};

vec16f sinev(vec16f angle)
{
	// Works better if angle is smaller
	angle = fmodv(angle, __builtin_vp_makevectorf(PI));

	vec16f angleSquared = angle * angle;
	vec16f numerator = angle;
	vec16f result = angle;
	
	for (int i = 0; i < NUM_TERMS; i++)
	{
		numerator *= angleSquared;		
		vec16f term = numerator * __builtin_vp_makevectorf(denominators[i]);
		if (i & 1)
			result += term;
		else
			result -= term;
	}
	
	return result;
}

vec16f cosv(vec16f angle)
{
	return sinev(angle + __builtin_vp_makevectorf(PI * 0.5f));
}

vec16i* const kFrameBufferAddress = (vec16i*) 0x10000000;
const vec16i kXOffsets = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

int main()
{
	// Strands work on interleaved chunks of pixels.  The strand ID determines
	// the starting point.
	int myStrandId = __builtin_vp_get_current_strand();
	for (int frameNum = 0; ; frameNum++)
	{
		vec16i *ptr = kFrameBufferAddress + myStrandId;
		for (int y = 0; y < 480; y++)
		{
			for (int x = myStrandId * 16; x < 640; x += 64)
			{
				vec16i xv = kXOffsets + __builtin_vp_makevectori(x);
				vec16i yv = __builtin_vp_makevectori(y);
				vec16f ffv = __builtin_vp_makevectorf((float) frameNum);

				vec16f xfv = __builtin_vp_vitof(xv);
				vec16f yfv = __builtin_vp_vitof(yv);
				vec16f intensity = sinev(xfv * __builtin_vp_makevectorf(0.005f));
				intensity += sinev((yfv + ffv) * __builtin_vp_makevectorf(0.01f));

				intensity = intensity * __builtin_vp_makevectorf(48.0f)
					+ __builtin_vp_makevectorf(128.0f);
				vec16i iintensity = __builtin_vp_vftoi(intensity);
				vec16i pixelValues = iintensity;
				pixelValues |= iintensity << __builtin_vp_makevectori(8);
				pixelValues |= iintensity << __builtin_vp_makevectori(16);
				*ptr = pixelValues;

				ptr += 4;	// Skip over four chunks because there are four threads.
			}
		}
	}

	return 0;
}
