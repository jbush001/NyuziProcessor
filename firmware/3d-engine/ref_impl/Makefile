
SRCS=LinearInterpolator.cpp \
	PixelShader.cpp \
	Rasterizer.cpp \
	OutputBuffer.cpp \
	PixelShaderState.cpp \
	main.cpp

render: FORCE
	g++ -o render $(SRCS) 
	./render
	../../../tools/mkbmp/mkbmp image.raw image.bmp 256 256
	
FORCE:
