# 
# Copyright 2011-2012 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 

SRCS=LinearInterpolator.cpp \
	PixelShader.cpp \
	Rasterizer.cpp \
	OutputBuffer.cpp \
	PixelShaderState.cpp \
	PrimitiveAssembly.cpp \
	main.cpp

render: FORCE
	g++ -o render $(SRCS) 
	./render
	../../../tools/mkbmp/mkbmp image.raw image.bmp 256 256
	
FORCE:
