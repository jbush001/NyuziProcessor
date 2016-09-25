ENTRY(_start)
SECTIONS {
  . = 0xfffee000;
  .text : { *(.text) }
  .data : { *(.data) }
  .bss  : { *(.bss) }
}
