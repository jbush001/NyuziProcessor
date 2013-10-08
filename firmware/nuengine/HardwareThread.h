#ifndef __HARDWARE_THREAD_H
#define __HARDWARE_THREAD_H

const int kMaxThreads = 4;

class Fiber;

class HardwareThread
{
public:
	static inline HardwareThread *currentThread();

private:
	friend class Fiber;

	static HardwareThread sThreads[kMaxThreads];
	Fiber *fCurrentFiber;
};

#endif

inline HardwareThread *HardwareThread::currentThread()
{
	return &sThreads[__builtin_vp_get_current_strand()];
}
