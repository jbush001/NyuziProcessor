This benchmark tests raw memory transfer speeds for reads, writes, and copies.  It attempts to 
saturate the memory interface by using vector wide transfers and splitting the copy between
multiple hardware threads to hide memory latency.

This currently only runs in Verilog simulation.  It can be executed by typing:

    ./runtest.sh