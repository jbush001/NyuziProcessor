#
# Copyright 2015-2017 Jeff Bush
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

#
# This defines the container used on TravisCI to build Nyuzi and
# run tests. It contains the toolchain and verilator. It is invoked from
# build-container.sh
#

FROM ubuntu:16.04
MAINTAINER Jeff Bush (https://github.com/jbush001)
RUN apt-get update && apt-get install -y make gcc g++ python3 perl libsdl2-dev imagemagick git cmake python3-pip
RUN pip3 install --upgrade pip
RUN pip3 install pillow
ADD tmp/clang-9 /usr/local/llvm-nyuzi/bin/
ADD tmp/elf2hex /usr/local/llvm-nyuzi/bin/
ADD tmp/lld /usr/local/llvm-nyuzi/bin/
ADD tmp/llvm-ar /usr/local/llvm-nyuzi/bin/
ADD tmp/llvm-ranlib /usr/local/llvm-nyuzi/bin/
ADD tmp/llvm-objdump /usr/local/llvm-nyuzi/bin/
ADD tmp/libclang_rt.builtins-nyuzi.a /usr/local/llvm-nyuzi/lib/clang/9.0.0/lib/
RUN ln -s /usr/local/llvm-nyuzi/bin/clang-9 /usr/local/llvm-nyuzi/bin/clang
RUN ln -s /usr/local/llvm-nyuzi/bin/clang-9 /usr/local/llvm-nyuzi/bin/clang++
RUN ln -s /usr/local/llvm-nyuzi/bin/lld /usr/local/llvm-nyuzi/bin/ld.lld
ADD tmp/share_verilator/ /usr/local/share/verilator/
ADD tmp/verilator* /usr/local/bin/
