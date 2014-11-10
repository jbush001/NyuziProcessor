#ifndef __DEVICE_H
#define __DEVICE_H

int openBlockDevice(const char *filename);
void closeBlockDevice();
void writeDeviceRegister(unsigned int address, unsigned int value);
unsigned readDeviceRegister(unsigned int address);

#endif
