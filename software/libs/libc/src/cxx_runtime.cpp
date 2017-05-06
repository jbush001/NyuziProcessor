//
// Copyright 2011-2015 Jeff Bush
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

namespace __cxxabiv1
{
class __class_type_info
{
public:
    __class_type_info() {}
    virtual ~__class_type_info() {}
};

class __si_class_type_info
{
public:
    __si_class_type_info() {}
    virtual ~__si_class_type_info() {}
};

__class_type_info cti;
__si_class_type_info sicti;
}

void *__dso_handle;

namespace {

struct AtExitCallback
{
    AtExitCallback *next;
    void (*func)(void *);
    void *data;
};

AtExitCallback *gAtExitList;
}

namespace std {
class bad_alloc {
};
};

void *operator new(size_t size) throw(std::bad_alloc)
{
    return malloc(size);
}

void operator delete(void *ptr) throw()
{
    return free(ptr);
}

void *operator new[](size_t size) throw(std::bad_alloc)
{
    return malloc(size);
}

void operator delete[](void *ptr) throw()
{
    return free(ptr);
}

extern "C" void __cxa_atexit(void (*func)(void *), void *objptr, void *dso)
{
    (void) dso;

    AtExitCallback *callback = new AtExitCallback();

    // Destructor functions are called in the reverse order that they
    // are registered (the most recently registered function ise called
    // first). Put at the beginning of the list.
    callback->next = gAtExitList;
    gAtExitList = callback;
    callback->func = func;
    callback->data = objptr;
}

extern "C" void call_atexit_functions()
{
    for (AtExitCallback *callback = gAtExitList; callback;
        callback = callback->next)
        callback->func(callback->data);
}

extern "C" void __cxa_pure_virtual()
{
    puts("Pure Virtual Function Call");
    __builtin_trap();
}

