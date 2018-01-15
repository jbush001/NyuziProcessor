#
# Copyright 2018 Jeff Bush
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

include(nyuzi)

add_nyuzi_library(compiler-rt
    ashldi3.s
    divsi3.c
    lshrdi3.s
    modsi3.c
    udivsi3.s
    umodsi3.c
    divdi3.c
    floatundisf.c
    moddi3.c
    udivdi3.c
    umoddi3.c)
