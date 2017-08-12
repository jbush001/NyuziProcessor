#!/usr/bin/perl -w

## -w for warnings

use strict 'vars';

use File::Basename;
use Cwd 'abs_path';

my $path = abs_path(dirname $0);

##################
## config

my $config_path = "$path/../build/vcs.config";

if (! -f $config_path) {
    die "ERROR: You need to have a $config_path file for this script to work";
}

my %config = do "$config_path";

##################
## VCS version 

my $vcs_path = $config{vcs_path};

print "INFO: Using vcs at $vcs_path\n";

if (!-d $vcs_path) {
    die "ERROR: Path for vcs <$vcs_path> is not valid";
}

my $vcs_sva_path = "$vcs_path/packages/sva";

##################
## VERDI version 

my $verdi_path = "$config{verdi_path}";

if (!-d $verdi_path) {
    die "ERROR: Path for verdi <$verdi_path> is not valid";
}

print "INFO: Using verdi at $verdi_path\n";

##################
## Compile command

my $verdi_tab = "$verdi_path/5.x/share/PLI/VCS/LINUX/novas.tab";
my $verdi_pli = "$verdi_path/5.x/share/PLI/VCS/LINUX/pli.a";

my $dump_fsdb="";
if ($ENV{DUMP_WAVEFORM}) {
    $dump_fsdb="DUMP_FSDB";
}

my $top = "$path/../hardware/testbench/TOP.sv";

if (!-f $top) {
    die "ERROR: Couldn't find file $top";
}

my $testbench = "$path/../hardware/testbench";
my $core = "$path/../hardware/core";
my $common = "$path/../hardware/fpga/common";

my $simv = "$path/simv";
my $y_path = "-y $testbench -y $core -y $common -y $vcs_sva_path";
my $inc_path = "+incdir+${core}+${vcs_sva_path}";
my $vcs_log = "$path/vcs.log";

my $command = "cd $path;vcs -o $simv -cc gcc $y_path +libext+.sv+.v+.h -sverilog $inc_path -debug +vpi +vcsd -P $verdi_tab $verdi_pli $top +define+$dump_fsdb+VCS+FSDBFN=\\\"trace.fsdb\\\"+SIMULATION +lint=all,noVCDE +error+100 +vcs+initreg+random -l $vcs_log"; 

print "Executing $command\n";

open COMMAND, "$command |" or die "ERROR: Couldn't execute command: $!";

while (<COMMAND>) {
    print $_;
}

close COMMAND;

exit 0;

