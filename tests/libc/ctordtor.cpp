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

#include <stdio.h>
#include <stdlib.h>

//
// Test that global constructors and destructors are called properly.
//

class GlobalObj
{
public:
    explicit GlobalObj(char *_name)
        : name(_name)
    {
        printf("%s constructor\n", name);
    }

    ~GlobalObj()
    {
        printf("%s destructor\n", name);
    }

private:
    char *name;
};

GlobalObj gObj1("foo");
GlobalObj gObj2("bar");

int main()
{
    printf("main\n");
    return 0;
    // CHECK: foo constructor
    // CHECK: bar constructor
    // CHECK: main
    // CHECK: bar destructor
    // CHECK: foo destructor
}
