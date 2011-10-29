1. To configure in Eclipse:
  - Open debug perspective (in upper right corner of eclipse workspace)
  - Run -> Debug Configurations
  - Debugger tab
  - Debugger type dropdown should be 'gdb/mi'
  - Select a.out as the debugger.
  - Protocol should be 'mi'
  - Make sure 'verbose console mode' is checked.  You can see GDB commands
    in the eclipse console window
