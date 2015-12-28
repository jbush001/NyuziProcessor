#!/bin/bash

(cd tests/cosimulation
./generate_random.py -m 3
./generate_random.py -i -o random-interrupt.s)
make test
