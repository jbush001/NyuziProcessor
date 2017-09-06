/*
 * This script forces all code to be emitted at address 0 and packs
 * the segments together without page aligning them. It must be used
 * with the linker flag '--oformat binary', and assumes the program
 * doesn't have initialized writable data. It is used by some tests
 * that make strict assumptions about the memory layout.
 */
ENTRY(_start)
SECTIONS {
  . = 0;
  .text : { *(.text) }
  .data : { *(.data) }
  .bss  : { *(.bss) }
}