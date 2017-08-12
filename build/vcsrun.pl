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
## VERDI version 

my $verdi_path = "$config{verdi_path}";

if (!-d $verdi_path) {
    die "ERROR: Path for verdi <$verdi_path> is not valid";
}

print "INFO: Using verdi at $verdi_path\n";

if (defined $ENV{'LD_LIBRARY_PATH'}) {
    $ENV{'LD_LIBRARY_PATH'} = "$verdi_path/5.x/share/PLI/lib/LINUX:$ENV{'LD_LIBRARY_PATH'}";
}
else {
    $ENV{'LD_LIBRARY_PATH'} = "$verdi_path/5.x/share/PLI/lib/LINUX";
}

##################
## Simulation command

## Dump multidimensional arrays 
$ENV{'NOVAS_FSDB_MDA'} = "1"; ## does both packed and unpacked
##$ENV{'NOVAS_FSDB_MDA_PACKONLY'} = "1";

# +randomize=*enable*             | Randomize initial register and memory values. Used to verify reset handling. Defaults to on.
# +randseed=*seed*                | If randomization is enabled, set the seed for the random number generator.

## $#ARGV is -1 when no arguments are passed
## $#ARGV+1 is the total number passed

my $t1 = time;

my $randomize_en = 1; ## default is enabled
my $randseed = $t1;

for (my $idx = 0; $idx <= $#ARGV; $idx++) {
    my $arg = $ARGV[$idx];
    if ($arg =~ /\+randomize/) {
	if ($arg =~ /\+randomize=e.*/ || $arg =~ /\+randomize=1/) {
	    $randomize_en = 1; 
	}
	elsif ($arg =~ /\+randomize=d.*/ || $arg =~ /\+randomize=0/) {
	    $randomize_en = 0; 
	}
	else {
	    $randomize_en = 1; 
	    print "INFO: Unexpected $arg value. Options are +randomize=enable|1|disable|0. Ignoring...\n";
	}
    }
    elsif ($arg =~ /\+randseed/) {
	if ($arg =~ /\+randseed=([0-9]+)/) {
	    my $val = $1;
	    if ($val == 0 || $val == 1) {
		$randseed = $t1;
		print "INFO: Unexpected $arg value. Options are +randseed=<seed>, seed cannot be 0 or 1. Ignoring...\n";
	    }
	    else {
		$randseed = $val; 
	    }
	}
	else {
	    $randseed = $t1;
	    print "INFO: Unexpected $arg value. Options are +randseed=<seed>. Ignoring...\n";
	}
    }
}

print "INFO: Random seed is $randseed\n";

my $vcs_init_reg;
if ($randomize_en) {
    printf "INFO: randomizing the initial values of registers and SRAMs.\n";
    $vcs_init_reg = "+vcs+init+$randseed";
}
else {
    printf "INFO: zeroing the initial values of registers and SRAMs.\n";
    $vcs_init_reg = "+vcs+init+0";
}

my $simv = "$path/simv";
my $command = "$simv $vcs_init_reg +vcs+lic+wait @ARGV";

if (!-f $simv) {
    die "ERROR: You must run sssim.pl on the directory where your $simv executable is located";
}

print "Executing $command\n";

open COMMAND, "$command |" or die "ERROR: Couldn't execute command: $!";

while (<COMMAND>) {
    print $_;
}

close COMMAND;

exit 0;

