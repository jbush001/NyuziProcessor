
volatile void **foo;

void __attribute__((noinline)) loop5000() {
    for (int i = 0; i < 5000; i++) {
        foo = (void*) *foo;
    }
}

void __attribute__((noinline)) loop10000() {
    for (int i = 0; i < 10000; i++) {
        foo = (void*) *foo;
    }
}

void __attribute__((noinline)) loop20000() {
    for (int i = 0; i < 20000; i++) {
        foo = (void*) *foo;
    }
}


int main()
{
    foo = (void*) &foo;
    loop5000();
    loop10000();
    loop20000();
    return 0;
}
