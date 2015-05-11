The visualizer app displays thread states across time. The +statetrace flag 
will cause the  verilog simulator will dump state traces to a text file 
called statetrace.txt, which this file reads:

    bin/verilator_model +statetrace=1 +bin=<image name>

Launch the visualizer as follows:

    java -jar bin/visualizer.jar statetrace.txt

A window will pop up which will display the trace.  It displays each thread 
as a horizontal strip.

![state-trace](https://raw.github.com/wiki/jbush001/NyuziProcessor/state-trace.png)

- Black: Instruction FIFO is empty (either an instruction cache miss or the restart 
  penalty after it rolls back a thread)
- Red: Data cache load miss or store buffer is full.
- Yellow: Operand dependency
- Orange: Writeback conflict.  Instructions with different latencies would arrive 
  at the writeback stage at the same time.
- Green: Thread is ready to run

The narrow blue strip at the bottom shows when the processor issues instructions.  
Gaps represent times when it cannot issue an instruction because all threads are 
blocked.
