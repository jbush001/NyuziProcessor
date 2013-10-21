NAME=copy3
BASEDIR=../..

mkdir -p WORK
$BASEDIR/tools/assembler/assemble -o WORK/$NAME.hex $NAME.asm

#vvp $BASEDIR/rtl/sim.vvp +statetrace=statetrace.txt +bin=WORK/$NAME.hex +simcycles=60000

# use verilator
$BASEDIR/rtl/obj_dir/Vverilator_tb +statetrace=statetrace.txt +bin=WORK/$NAME.hex

