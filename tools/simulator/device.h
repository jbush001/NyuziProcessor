#ifndef __DEVICE_H
#define __DEVICE_H

void writeDeviceRegister(unsigned int address, unsigned int value);
unsigned readDeviceRegister(unsigned int address);

#endif
