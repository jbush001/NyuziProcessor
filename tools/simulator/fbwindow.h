#ifndef __FBWINDOW_H
#define __FBWINDOW_H

int initFB(int width, int height);
void updateFB(void *base);
void pollEvent();

#endif
