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

project(tools)

add_subdirectory(emulator)
add_subdirectory(mkfs)
add_subdirectory(serial_boot)
add_subdirectory(repak)
add_subdirectory(misc)
add_subdirectory(visualizer EXCLUDE_FROM_ALL)
