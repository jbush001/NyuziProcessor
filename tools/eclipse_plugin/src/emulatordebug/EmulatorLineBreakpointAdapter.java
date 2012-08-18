// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

package emulatordebug;

import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.debug.core.DebugPlugin;
import org.eclipse.debug.core.model.IBreakpoint;
import org.eclipse.debug.core.model.ILineBreakpoint;
import org.eclipse.debug.ui.actions.IToggleBreakpointsTarget;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.ui.IWorkbenchPart;
import org.eclipse.ui.texteditor.ITextEditor;
import org.eclipse.jface.text.ITextSelection;

public class EmulatorLineBreakpointAdapter implements IToggleBreakpointsTarget
{
	public EmulatorLineBreakpointAdapter()
	{
	}
	
	public boolean canToggleLineBreakpoints(IWorkbenchPart arg0, ISelection arg1)
	{
		return true;
	}

	public boolean canToggleMethodBreakpoints(IWorkbenchPart arg0,
			ISelection arg1)
	{
		// TODO Auto-generated method stub
		return false;
	}

	public boolean canToggleWatchpoints(IWorkbenchPart arg0, ISelection arg1)
	{
		// TODO Auto-generated method stub
		return false;
	}

	public void toggleLineBreakpoints(IWorkbenchPart part, ISelection selection)
			throws CoreException
	{
		EmulatorDebugTarget target = EmulatorDebugTarget.getInstance();

		ITextEditor editor = (ITextEditor) part;
		IResource resource = (IResource) editor.getEditorInput().getAdapter(IResource.class);
		
		String filename = editor.getEditorInput().getName();
		int lineNumber = ((ITextSelection)selection).getStartLine() + 1;

		// Determine if this breakpoint should be enabled or disabled
		IBreakpoint[] breakpoints = DebugPlugin.getDefault().getBreakpointManager()
			.getBreakpoints("emulatordebug.EmulatorDebugModel");
		for (IBreakpoint breakpoint : breakpoints)
		{
			try
			{
				if (breakpoint instanceof ILineBreakpoint)
				{
					ILineBreakpoint lineBreakpoint = (ILineBreakpoint) breakpoint;
					if (lineBreakpoint.getLineNumber() == lineNumber)
					{
						// Breakpoint already exists, turn it off
						breakpoint.delete();
						if (target != null)
							target.clearBreakpoint(resource, filename, lineNumber);

						return;
					}
				}
			}
			catch (CoreException e)
			{
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}

		// Create breakpoint
		if (target == null)
		{
			// If the emulator is not yet running, just set the breakpoint now on the current line.
			// when the emulator starts, it will install the breakpoint and adjust line numbers
			// as necessary to put them on executable lines.
			try
			{
				DebugPlugin.getDefault().getBreakpointManager().addBreakpoint(new EmulatorLineBreakpoint(resource, lineNumber));
			}
			catch (Exception e)
			{
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
		else
			target.setBreakpoint(resource, filename, lineNumber);
	}

	public void toggleMethodBreakpoints(IWorkbenchPart arg0, ISelection arg1)
			throws CoreException
	{
		// TODO Auto-generated method stub

	}

	public void toggleWatchpoints(IWorkbenchPart arg0, ISelection arg1)
			throws CoreException
	{
		// TODO Auto-generated method stub

	}
}
