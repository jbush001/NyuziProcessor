ENTRY(_start)
SECTIONS {
  . = 0xfffee000;
  _start = .;
  .text : {
    *(.text)
    *(.rodata)
    *(.eh_frame)
  }
  .data : { *(.data) }
  .bss  : { *(.bss) }
}
