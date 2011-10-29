package emulatordebug;

import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.debug.core.ILaunchConfiguration;
import org.eclipse.debug.core.sourcelookup.ISourceContainer;
import org.eclipse.debug.core.sourcelookup.ISourcePathComputerDelegate;
import org.eclipse.debug.core.sourcelookup.containers.WorkspaceSourceContainer;

public class EmulatorSourcePathComputerDelegate implements
		ISourcePathComputerDelegate
{
	public ISourceContainer[] computeSourceContainers(
			ILaunchConfiguration arg0, IProgressMonitor arg1)
			throws CoreException
	{
		return new ISourceContainer[]{ new WorkspaceSourceContainer() };
	}
}
