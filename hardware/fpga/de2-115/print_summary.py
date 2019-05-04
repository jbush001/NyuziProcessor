#!/usr/bin/env python3
#
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

import re

#
# Pull some basic metrics out of the report files and print them
#

speed_re = re.compile(r'(?P<speed>[0-9\.]+) MHz')
with open('output_files/de2_115.sta.rpt') as f:
    found_section = False
    for line in f:
        if found_section:
            got = speed_re.search(line)
            if got is not None:
                print('Fmax {} MHz'.format(got.group('speed')))
                break
        elif line.find('; Slow 1200mV 85C Model Fmax Summary') != -1:
            found_section = True

count_re = re.compile('(?P<num>[0-9,]+)')
with open('output_files/de2_115.fit.rpt') as f:
    for line in f:
        if 'Total logic elements' in line:
            got = count_re.search(line)
            if got is not None:
                print('{} Logic elements'.format(got.group('num')))
                break
