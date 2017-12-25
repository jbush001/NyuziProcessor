#
# Reset the dev board by writing to a virtual JTAG register
# that is connected to the reset line.
#

set hardware [lindex [get_hardware_names] 0]
set device [lindex [get_device_names -hardware_name $hardware ] 0]
open_device -hardware_name $hardware -device_name $device
device_lock -timeout 10000
device_virtual_dr_shift -instance_index 0 -dr_value 1 -length 1
device_virtual_dr_shift -instance_index 0 -dr_value 0 -length 1
device_unlock

