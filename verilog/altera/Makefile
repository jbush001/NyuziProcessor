# The QSF file contains all of the settings for this project.  All of these
# files will find that file and read it.
# The quartus binary dir must be in the current PATHi environment variable.  
# For example:
#   PATH=$PATH:~/altera/11.0sp1/quartus/bin/

PROJECT=fpga_target
SOURCES=*.v ../rtl/*.v

all: $(PROJECT).asm.rpt 

$(PROJECT).map.rpt: $(SOURCES) $(PROJECT).qsf
	quartus_map $(PROJECT)

$(PROJECT).fit.rpt: $(PROJECT).map.rpt 
	quartus_fit $(PROJECT)

$(PROJECT).asm.rpt: $(PROJECT).fit.rpt
	quartus_asm $(PROJECT)


