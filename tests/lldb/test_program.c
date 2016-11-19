

int globalvar;

int sub_func(int a, int b)
{
    globalvar = a + b;
}

int main()
{
    sub_func(12, 7);
}

