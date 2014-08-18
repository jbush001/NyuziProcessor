The visualizer app allows viewing thread states across time.  

_Note: Capturing state traces currently is not working in the simulator_

Run the visualizer app on a trace file:

    java -jar <project top>/tools/visualizer/visualizer.jar states.txt

A window will pop up which will display states.  Each strand is displayed as a horizontal strip.

![state-trace](https://raw.github.com/wiki/jbush001/GPGPU/state-trace.png)

- Black indicates a thread that is unable to run because it is waiting on the instruction cache (
either an instruction cache miss or the restart penalty after a thread is rolled back)
- Red indicates a thread that is waiting on the data cache or because the store buffer is full.
- Yellow indicates a thread that is waiting because of a RAW dependency.
- Green indicates a thread that is ready to run

The narrow blue strip at the bottom shows when instructions are issued.  Gaps represent times when no instruction can be issued because all threads are blocked.
