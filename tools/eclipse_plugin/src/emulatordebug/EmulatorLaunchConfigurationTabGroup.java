package emulatordebug;

import org.eclipse.debug.core.ILaunch;
import org.eclipse.debug.core.ILaunchConfiguration;
import org.eclipse.debug.core.ILaunchConfigurationWorkingCopy;
import org.eclipse.debug.ui.ILaunchConfigurationDialog;
import org.eclipse.debug.ui.ILaunchConfigurationTab;
import org.eclipse.debug.ui.ILaunchConfigurationTabGroup;

public class EmulatorLaunchConfigurationTabGroup implements
		ILaunchConfigurationTabGroup {

	@Override
	public void createTabs(ILaunchConfigurationDialog arg0, String arg1) {
		// TODO Auto-generated method stub
		fTabs = new ILaunchConfigurationTab[] {
				new EmulatorLaunchConfigurationTab()
		};
	}
	

	@Override
	public void dispose() {
		// TODO Auto-generated method stub

	}

	@Override
	public ILaunchConfigurationTab[] getTabs() {
		// TODO Auto-generated method stub
		return fTabs;
	}

	@Override
	public void initializeFrom(ILaunchConfiguration arg0) {
		// TODO Auto-generated method stub

	}

	@Override
	public void launched(ILaunch arg0) {
		// TODO Auto-generated method stub

	}

	@Override
	public void performApply(ILaunchConfigurationWorkingCopy arg0) {
		// TODO Auto-generated method stub

	}

	@Override
	public void setDefaults(ILaunchConfigurationWorkingCopy arg0) {
		// TODO Auto-generated method stub

	}

	ILaunchConfigurationTab[] fTabs;
}
