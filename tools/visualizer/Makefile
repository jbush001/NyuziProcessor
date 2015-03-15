# 
# Copyright 2011-2015 Jeff Bush
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


BINDIR=../../bin
TARGET=$(BINDIR)/visualizer.jar
SOURCES = 	VisualizerApp.java  \
			TraceView.java \
			TraceModel.java

all: $(TARGET) $(BINDIR)

$(TARGET): $(SOURCES) manifest CLASSDIR
	javac -g $(SOURCES) -d CLASSDIR
	jar cvfm $@ manifest -C CLASSDIR .

clean:
	rm -rf CLASSDIR
	rm $(TARGET)
	
$(BINDIR):
	mkdir -p $(BINDIR)

CLASSDIR: 
	mkdir CLASSDIR
