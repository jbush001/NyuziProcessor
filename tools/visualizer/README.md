The visualizer app allows viewing thread states across time. State traces can be dumped
by using the +statetrace=1 flag on the verilator command line:

    bin/verilator_model +statetrace=1 +bin=<image name>

The trace file can be viewed as follows:

    java -jar bin/visualizer.jar statetrace.txt

A window will pop up which will display states.  Each strand is displayed as a horizontal strip.

![state-trace](https://raw.github.com/wiki/jbush001/NyuziProcessor/state-trace.png)

- Black: Instruction FIFO is empty (
either an instruction cache miss or the restart penalty after a thread is rolled back)
- Red: Data cache load miss or store buffer is full.
- Yellow: Operand dependency
- Orange: Writeback conflict.  Instructions with different latencies would arrive at the writeback stage at the same time.
- Green: Thread is ready to run

The narrow blue strip at the bottom shows when instructions are issued.  Gaps represent times when no instruction can be issued because all threads are blocked.
