#!/usr/bin/env python3
#
# Copyright 2016 Jeff Bush
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

"""Convert a binary file into a file compatible with Verilog $readmemh.

Each line in this file will be a 4 byte hexadecimal value. This is used
primarily to create a bootloader file that can be read by the synthesis
tools.
"""

import sys
import binascii

def main():
    with open(sys.argv[1], 'rb') as f:
        while True:
            word = f.read(4)
            if not word:
                break

            print(binascii.hexlify(word).decode())

if __name__ == '__main__':
    main()
