//
// Copyright 2016 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

int globalvar;

int func2(int value)
{
    int i;
    int result = 0;

    for (i = 0; i < 5; i++)
        result += value >> i;

    result >>= 1;

    return result;
}

int func1(int a, int b)
{
    b += a * globalvar;
    return func2(b);
}

int main()
{
    globalvar = 5;
    func1(12, 7);
}

