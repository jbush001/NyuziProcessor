import math

OUTER_STEPS = 12
INNER_STEPS = 12

#
# Build vertex list
#
INNER_DIAMETER = 0.2
OUTER_DIAMETER = 0.5

print 'const int kNumTorusVertices = %d;' % (OUTER_STEPS * INNER_STEPS)
print 'const float kTorusVertices[] = {'

for outerStep in range(OUTER_STEPS):
	outerR = outerStep * 2.0 * math.pi / OUTER_STEPS
	for innerStep in range(INNER_STEPS):
		innerR = innerStep * 2.0 * math.pi / INNER_STEPS
		
		innerDist = math.cos(innerR) * INNER_DIAMETER
		x = math.sin(outerR) * (innerDist + OUTER_DIAMETER)
		y = math.cos(outerR) * (innerDist + OUTER_DIAMETER)
		z = math.sin(innerR) * INNER_DIAMETER

		centerX = math.sin(outerR) * OUTER_DIAMETER
		centerY = math.cos(outerR) * OUTER_DIAMETER
		
		normalX = (x - centerX) / INNER_DIAMETER
		normalY = (y - centerY) / INNER_DIAMETER
		normalZ = z / INNER_DIAMETER
		
		print '\t%#0.10gf, %#0.10gf, %#0.10gf, %#0.10gf, %#0.10gf, %#0.10gf,' % (x, y, z, normalX, normalY, normalZ)

print '};'

# 
# Build index list
#

print 'const int kNumTorusIndices = %d;' % (OUTER_STEPS * INNER_STEPS * 6)
print 'const int kTorusIndices[] = {'

def stepWrappingOuter(x):
	return (x + 1) % OUTER_STEPS

def stepWrappingInner(x):
	return (x + 1) % INNER_STEPS

for outerStep in range(OUTER_STEPS):
	for innerStep in range(INNER_STEPS):
		print '\t%d, %d, %d,' % (
			stepWrappingOuter(outerStep) * INNER_STEPS + stepWrappingInner(innerStep),
			(outerStep * INNER_STEPS) + stepWrappingInner(innerStep), 
			(outerStep * INNER_STEPS) + innerStep)
		print '\t%d, %d, %d,' % (
			outerStep * INNER_STEPS + innerStep,
			stepWrappingOuter(outerStep) * INNER_STEPS + innerStep,
			stepWrappingOuter(outerStep) * INNER_STEPS + stepWrappingInner(innerStep))

print '};'
