package emulatordebug;

import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.Status;
import org.eclipse.debug.core.ILaunch;
import org.eclipse.debug.core.ILaunchConfiguration;
import org.eclipse.debug.core.model.ILaunchConfigurationDelegate;
import org.eclipse.jface.dialogs.ErrorDialog;
import org.eclipse.ui.PlatformUI;

public class EmulatorLaunchConfigurationDelegate implements
		ILaunchConfigurationDelegate {

	public void launch(ILaunchConfiguration arg0, String arg1, ILaunch launch,
		IProgressMonitor arg3) throws CoreException {
		launch.addDebugTarget(new EmulatorDebugTarget(launch));
	}
}
