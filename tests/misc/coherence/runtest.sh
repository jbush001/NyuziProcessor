NAME=coherence
BASEDIR=../../..

mkdir -p WORK
$BASEDIR/tools/assembler/assemble -o WORK/$NAME.hex $NAME.asm

vvp $BASEDIR/rtl/sim.vvp +bin=WORK/$NAME.hex +simcycles=300 +trace=trace.vcd

