NAME=coherence
BASEDIR=../../..

mkdir -p WORK
$BASEDIR/tools/assembler/assemble -o WORK/$NAME.hex $NAME.asm
$BASEDIR/rtl/obj_dir/Vverilator_tb +bin=WORK/$NAME.hex

