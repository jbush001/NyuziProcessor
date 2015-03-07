This benchmark approximates the workload of Bitcoin hashing.  It performs parallel SHA-256 hashes, with
one hash instance per vector lane.  It utilizes multiple hardware threads, so there are 64 hashes active 
per core.
