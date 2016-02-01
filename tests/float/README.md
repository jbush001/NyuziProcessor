Make tests:

    cc -o gen_cases gen_cases.c
    ./gen_cases > test_cases.inc

Execute against emulator:

    make test

Execute against verilator:

    make vtest
