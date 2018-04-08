#!/bin/bash
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
# This creates the container used on TravisCI to build Nyuzi and
# run tests. It copies the files into a temporary directory, uses
# the Dockerfile in this directory to create the container, then uploads
# them to a dockerhub account. Set the variable DOCKER_REPO to the
# appropriate path, eg.:
#
# DOCKER_REPO=username/nyuzi-build ./build_container.sh
#

TOOLCHAIN_DIR=/usr/local/llvm-nyuzi/

rm -rf tmp/*
mkdir -p tmp
cp $TOOLCHAIN_DIR/bin/clang-7 tmp/
cp $TOOLCHAIN_DIR/bin/elf2hex tmp/
cp $TOOLCHAIN_DIR/bin/lld tmp/
cp $TOOLCHAIN_DIR/bin/llvm-ar tmp/
cp $TOOLCHAIN_DIR/bin/llvm-ranlib tmp/
cp $TOOLCHAIN_DIR/bin/llvm-objdump tmp/
cp $TOOLCHAIN_DIR/lib/clang/7.0.0/lib/libclang_rt.builtins-nyuzi.a tmp/

cp -R /usr/local/share/verilator tmp/share_verilator
cp /usr/local/bin/verilator* tmp/

docker build -t $DOCKER_REPO:latest .
docker push $DOCKER_REPO

