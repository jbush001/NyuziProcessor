//
// Basic debugger howto: http://eclipse.org/articles/Article-Debugger/how-to.html
// See http://www.vogella.de/articles/EclipsePlugIn/article.html for how to make breakpoint adapters
//

package emulatordebug;

import org.eclipse.core.resources.IMarker;
import org.eclipse.core.resources.IMarkerDelta;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.Status;
import org.eclipse.debug.core.DebugEvent;
import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.DebugPlugin;
import org.eclipse.debug.core.ILaunch;
import org.eclipse.debug.core.model.IBreakpoint;
import org.eclipse.debug.core.model.IDebugTarget;
import org.eclipse.debug.core.model.ILineBreakpoint;
import org.eclipse.debug.core.model.IMemoryBlock;
import org.eclipse.debug.core.model.IProcess;
import org.eclipse.debug.core.model.IThread;
import org.eclipse.jface.dialogs.ErrorDialog;
import org.eclipse.jface.dialogs.MessageDialog;
import org.eclipse.jface.viewers.StructuredSelection;
import org.eclipse.swt.widgets.Display;
import org.eclipse.ui.IViewPart;
import org.eclipse.ui.IViewReference;
import org.eclipse.ui.IWorkbench;
import org.eclipse.ui.IWorkbenchPage;
import org.eclipse.ui.IWorkbenchWindow;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.navigator.CommonNavigator;
import org.eclipse.ui.navigator.CommonViewer;
import org.eclipse.ui.views.navigator.ResourceNavigator;

public class EmulatorDebugTarget extends EmulatorDebugElement implements IDebugTarget
{
	public EmulatorDebugTarget(ILaunch launch) throws CoreException
	{
		super(null);
		fLaunch = launch;
		fEmulatorProcess = new EmulatorProcess();
		fEmulatorProcess.registerUnsolicitedCallback("breakpoint-hit", fEmulatorProcess.new Callback(){
			void invoke(String[] result) { suspendCallback(result, DebugEvent.BREAKPOINT); }
		});

		fEmulatorProcess.registerUnsolicitedCallback("started", fEmulatorProcess.new Callback(){
			void invoke(String[] result) { startedCallback(result); }
		});

		IProject project = getActiveProject();
		if (project == null)
		{
			 Display.getDefault().asyncExec(new Runnable() {
			    public void run() {
			      MessageDialog.openInformation(null, "Error", "No project is currently selected");
			    }
			 });

			 throw new CoreException(new Status(Status.OK, "emulatordebug.EmulatorDebugModel", "No project selected"));
		}
		
		fEmulatorProcess.connect(project.getName() + ".hex", project.getLocation().toFile());
		sInstance = this;
		
		installBreakpoints();
	}

	// I believe writing this function has seriously caused damage to my brain.
	IProject getActiveProject()
	{
		IWorkbench workbench = PlatformUI.getWorkbench();
		IWorkbenchWindow window = workbench.getWorkbenchWindows()[0];	// getActiveWorkbenchWindow returns null for non-UI thread...
		IWorkbenchPage page = window.getPages()[0];	// fails as above.  not sure what the difference between page and window is...

		// Find the package explorer.
		for (IViewReference ref : page.getViewReferences())
		{
			IViewPart part = ref.getView(false);
			if (part instanceof CommonNavigator)
			{
				CommonViewer viewer = ((CommonNavigator) part).getCommonViewer();
				StructuredSelection sel = (StructuredSelection) viewer.getSelection();
				IResource resource = (IResource) sel.getFirstElement();
				if (resource == null)
					return null;
				
				return resource.getProject();
			}
		}

		return null;
	}
	
	static EmulatorDebugTarget sInstance;
	
	static EmulatorDebugTarget getInstance()
	{
		return sInstance;
	}

	private void startedCallback(String[] result)
	{
		fCurrentFile = result[0];
		fCurrentLine = Integer.parseInt(result[1]);
		processChangedRegisters(result, 2);	// May be superfluous, since registers always start as zero
		fireCreationEvent();
	}
	
	public ILaunch getLaunch() 
	{
		return fLaunch;
	}
	
	public boolean canTerminate()
	{
		return !fIsTerminated;
	}

	public boolean isTerminated()
	{
		return fIsTerminated;
	}

	public void terminate() throws DebugException
	{
		fIsTerminated = true;
		fEmulatorProcess.disconnect();
		fireTerminateEvent();
		sInstance = null;		// Assuming this object will go away...
	}

	public boolean canResume()
	{
		return !fIsTerminated && !fIsRunning && !fIsStepping;
	}

	public boolean canSuspend()
	{
		return !fIsTerminated && fIsRunning && !fIsStepping;
	}

	public boolean isSuspended()
	{
		return !fIsRunning && !fIsStepping;
	}

	public boolean isStepping()
	{
		return fIsStepping;
	}
	
	public void resume() throws DebugException
	{
		fEmulatorProcess.sendCommand("resume", null);
		fIsRunning = true;
		fThreads[0].fireResumeEvent(DebugEvent.CLIENT_REQUEST);
	}

	public void suspend() throws DebugException
	{
		fEmulatorProcess.sendCommand("suspend",
			fEmulatorProcess.new Callback() { void invoke(String[] result) { 
			suspendCallback(result, DebugEvent.CLIENT_REQUEST); } });
	}
	
	public void breakpointAdded(IBreakpoint arg0)
	{
		// TODO Auto-generated method stub

	}

	public void breakpointChanged(IBreakpoint arg0, IMarkerDelta arg1)
	{
		// TODO Auto-generated method stub

	}

	public void breakpointRemoved(IBreakpoint arg0, IMarkerDelta arg1)
	{
		// TODO Auto-generated method stub

	}

	public boolean canDisconnect()
	{
		// TODO Auto-generated method stub
		return false;
	}

	public void disconnect() throws DebugException
	{
		// TODO Auto-generated method stub

	}

	@Override
	public boolean isDisconnected()
	{
		// TODO Auto-generated method stub
		return false;
	}

	public IMemoryBlock getMemoryBlock(long start, long length)
			throws DebugException
	{
		final TargetMemoryBlock block = new TargetMemoryBlock(this, start, length);
		fEmulatorProcess.sendCommand("read-memory " + start + " " + length,
			fEmulatorProcess.new Callback() { void invoke(String[] result) { 
			readMemoryCallback(result, block); } });
		
		return block;
	}

	public void readMemoryCallback(String[] args, TargetMemoryBlock block)
	{
		byte[] newValues = new byte[args.length];
		for (int i = 0; i < args.length; i++)
			newValues[i] = (byte)(Integer.parseInt(args[i], 16) & 0xff);

		block.setBytes(newValues);
	}
	
	public boolean supportsStorageRetrieval()
	{
		return true;
	}

	public String getName() throws DebugException
	{
		return "Emulator";
	}

	public IProcess getProcess()
	{
		return null;
	}

	public IThread[] getThreads() throws DebugException
	{
		return fThreads;
	}

	public boolean hasThreads() throws DebugException
	{
		return true;
	}

	public boolean supportsBreakpoint(IBreakpoint arg0)
	{
		// TODO Auto-generated method stub
		return false;
	}

	public boolean canStepInto()
	{
		return !fIsRunning && !fIsStepping;
	}

	public boolean canStepOver()
	{
		return false;	// Currently not supported by emulator
	}

	public boolean canStepReturn()
	{
		return false;	// Currently not supported by emulator
	}

	synchronized public void stepInto() throws DebugException
	{
		fIsStepping = true;
		fThreads[0].fireResumeEvent(DebugEvent.STEP_INTO);
		fEmulatorProcess.sendCommand("step-into",
			fEmulatorProcess.new Callback() { void invoke(String[] result) { 
			suspendCallback(result, DebugEvent.STEP_INTO); } });
	}

	synchronized public void stepOver() throws DebugException
	{
		fIsStepping = true;
		fThreads[0].fireResumeEvent(DebugEvent.STEP_OVER);
		fEmulatorProcess.sendCommand("step-over",
			fEmulatorProcess.new Callback() { void invoke(String[] result) { 
			suspendCallback(result, DebugEvent.STEP_OVER); } });
	}

	synchronized public void stepReturn() throws DebugException
	{
		fIsStepping = true;
		fThreads[0].fireResumeEvent(DebugEvent.STEP_RETURN);
		fEmulatorProcess.sendCommand("step-return",
			fEmulatorProcess.new Callback() { void invoke(String[] result) { 
			suspendCallback(result, DebugEvent.STEP_RETURN); } });
	}

	// Called for any case where execution is suspended, including suspend or
	// stepping.
	// Arguments will be: <file> <lineno> [<reg> <value>...]
	synchronized public void suspendCallback(String[] result, int reason)
	{
		fIsStepping = false;
		fIsRunning = false;
		fCurrentFile = result[0];
		fCurrentLine = Integer.parseInt(result[1]);
		processChangedRegisters(result, 2);
		fThreads[0].updateStackFrames();
		fThreads[0].fireSuspendEvent(reason);
	}
	
	synchronized public void clearBreakpoint(final IResource resource, final String sourceFile, int line )
	{
		fEmulatorProcess.sendCommand("delete-breakpoint " + sourceFile + " " + line, null);
	}
	
	synchronized public void setBreakpoint(final IResource resource, final String sourceFile, int line)
	{
		fEmulatorProcess.sendCommand("set-breakpoint " + sourceFile + " " + line, fEmulatorProcess.new Callback() {
			void invoke(String[] result) { setBreakpointCallback(result, resource); } });
	}
	
	//
	// When the emulator is restarted, re-set all of the breakpoints that are currently active.
	//
	synchronized void installBreakpoints()
	{
		IBreakpoint[] breakpoints = DebugPlugin.getDefault().getBreakpointManager()
				.getBreakpoints("emulatordebug.EmulatorDebugModel");
		for (IBreakpoint breakpoint : breakpoints)
		{
			try
			{
				if (breakpoint instanceof ILineBreakpoint)
				{
					final ILineBreakpoint lineBreakpoint = (ILineBreakpoint) breakpoint;
					String sourceFile = breakpoint.getMarker().getResource().getName();
					fEmulatorProcess.sendCommand("set-breakpoint " + sourceFile + " " + lineBreakpoint.getLineNumber(), 
						fEmulatorProcess.new Callback() { void invoke(String[] result) { 
						initialSetBreakpointCallback(result, lineBreakpoint); } });
				}
			}
			catch (CoreException e)
			{
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
	}
	
	// This is called when setting up breakpoints installed before emulation started.  It may have to 
	// adjust breakpoints if they have moved.
	// XXX this does not handle the edge case where a breakpoint is moved and there end up being two breakpoints on a line.
	synchronized public void initialSetBreakpointCallback(String[] result, ILineBreakpoint breakpoint)
	{
		try
		{
			if (result[0].equals("breakpoint-set"))
			{
				// Breakpoint set
				int line = Integer.parseInt(result[1]);
				if (line != breakpoint.getLineNumber())
				{
					// Need to move this breakpoint to a line with executable code.
					breakpoint.getMarker().setAttribute(IMarker.LINE_NUMBER, line);
				}
			}
			else
			{
				// This breakpoint could not be set.  Mark it as disabled.
				breakpoint.getMarker().setAttribute(IBreakpoint.ENABLED, Boolean.FALSE);
			}
		}
		catch (Exception exc)
		{
			exc.printStackTrace();
		}
	}
	// Result: <sucess/failure code> <line>
	// Note that the emulator may round to the next valid line if the current line has no code, which is why
	// we get the value back. If this was unsuccessful (no code after current line), no breakpoint will be set.
	synchronized public void setBreakpointCallback(String[] result, IResource resource)
	{
		if (result[0].equals("breakpoint-set"))
		{
			try
			{
				int line = Integer.parseInt(result[1]);
				EmulatorLineBreakpoint breakpoint = new EmulatorLineBreakpoint(resource, line);
				DebugPlugin.getDefault().getBreakpointManager().addBreakpoint(breakpoint);
			}
			catch (Exception e)
			{
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
		
		// Otherwise the breakpoint couldn't be set.
	}
	
	public int getScalarRegisterValue(int register)
	{
		return fScalarRegisterValues[register];
	}
	
	public int[] getVectorRegisterValue(int register)
	{
		return fVectorRegisterValues[register];
	}
	
	public int getLineNumber()
	{
		return fCurrentLine;
	}
	
	public String getSourceName()
	{
		return fCurrentFile;
	}
	
	private void processChangedRegisters(String[] result, int firstIndex)
	{
		for (int i = firstIndex; i < result.length; i += 2)
		{
			char type = result[i].charAt(0);
			int regIndex = (int)(Long.parseLong(result[i].substring(1)) & 0xffffffff);
			if (type == 'v')
			{
				for (int lane = 0; lane < 16; lane++)
				{
					/// Need to parse long for signed...
					int value = (int) Long.parseLong(result[i + 1].substring(lane * 8,
						lane * 8 + 8), 16) & 0xffffffff;
					fVectorRegisterValues[regIndex][lane] = value;
				}
			}
			else
				fScalarRegisterValues[regIndex] = (int) (Long.parseLong(result[i + 1], 16) & 0xffffffff);
		}
	}

	private String fCurrentFile = "";	// XXX hack: only checks source file once
	private int fCurrentLine = 0;
	private TargetThread[] fThreads = new TargetThread[]{ new TargetThread(this) };
	private ILaunch fLaunch;
	private boolean fIsRunning = false;
	private boolean fIsStepping = false;
	private boolean fIsTerminated = false;
	private int[] fScalarRegisterValues = new int[32];
	private int[][] fVectorRegisterValues = new int[32][16];
	private EmulatorProcess fEmulatorProcess;
}
