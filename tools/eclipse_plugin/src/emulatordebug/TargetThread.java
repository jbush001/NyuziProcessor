package emulatordebug;

import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.model.IBreakpoint;
import org.eclipse.debug.core.model.IStackFrame;
import org.eclipse.debug.core.model.IThread;

public class TargetThread extends EmulatorDebugElement implements IThread
{
	public TargetThread(EmulatorDebugTarget target)
	{
		super(target);
		fRegisterGroups = new TargetRegisterGroup[] { 
			new TargetRegisterGroup(target, "i", "s"), 
			new TargetRegisterGroup(target, "v", "s"), 
			new TargetRegisterGroup(target, "i", "f"), 
			new TargetRegisterGroup(target, "v", "f") 
		};
		updateStackFrames();
	}
	
	public boolean canResume()
	{
		return getEmulatorDebugTarget().canResume();
	}

	public boolean canSuspend()
	{
		return getEmulatorDebugTarget().canSuspend();
	}

	public boolean isSuspended()
	{
		return getEmulatorDebugTarget().isSuspended();
	}

	public void resume() throws DebugException
	{
		getEmulatorDebugTarget().resume();
	}

	public void suspend() throws DebugException
	{
		getEmulatorDebugTarget().suspend();
	}

	public boolean canStepInto()
	{
		return getEmulatorDebugTarget().canStepInto();
	}

	public boolean canStepOver()
	{
		return getEmulatorDebugTarget().canStepOver();	
	}

	public boolean canStepReturn()
	{
		return getEmulatorDebugTarget().canStepReturn();
	}

	public boolean isStepping()
	{
		return getEmulatorDebugTarget().isStepping();
	}

	public void stepInto() throws DebugException
	{
		getEmulatorDebugTarget().stepInto();
	}

	public void stepOver() throws DebugException
	{
		getEmulatorDebugTarget().stepOver();
	}

	public void stepReturn() throws DebugException
	{
		getEmulatorDebugTarget().stepReturn();
	}

	public boolean canTerminate()
	{
		return getEmulatorDebugTarget().canTerminate();
	}

	public boolean isTerminated()
	{
		return getEmulatorDebugTarget().isTerminated();
	}

	public void terminate() throws DebugException
	{
		getEmulatorDebugTarget().terminate();
	}

	public IBreakpoint[] getBreakpoints()
	{
		// TODO Auto-generated method stub
		return null;
	}

	public String getName() throws DebugException
	{
		return "Main Thread";
	}

	public int getPriority() throws DebugException
	{
		return 0;
	}
	
	/// Eclipse assumes StackFrame objects are immutable and uses Object.equals() to determine if an object
	/// has been updated.  As such, we generate new objects whenever the values inside them changes.
	public void updateStackFrames()
	{
		fStackFrames = new TargetStackFrame[]{ new TargetStackFrame(getEmulatorDebugTarget(), this, fRegisterGroups) };
	}
	
	public IStackFrame[] getStackFrames() throws DebugException
	{
		return fStackFrames;
	}

	public IStackFrame getTopStackFrame() throws DebugException
	{
		return fStackFrames[fStackFrames.length - 1];
	}

	public boolean hasStackFrames() throws DebugException
	{
		return true;
	}
	
	private TargetStackFrame[] fStackFrames;
	private TargetRegisterGroup[] fRegisterGroups;
}
