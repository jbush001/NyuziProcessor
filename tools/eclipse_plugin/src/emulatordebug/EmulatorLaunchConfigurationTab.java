package emulatordebug;

import org.eclipse.debug.core.ILaunch;
import org.eclipse.debug.core.ILaunchConfiguration;
import org.eclipse.debug.core.ILaunchConfigurationWorkingCopy;
import org.eclipse.debug.ui.ILaunchConfigurationDialog;
import org.eclipse.debug.ui.ILaunchConfigurationTab;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Control;

public class EmulatorLaunchConfigurationTab implements ILaunchConfigurationTab 
{
	public void activated(ILaunchConfigurationWorkingCopy arg0) {
	}

	public boolean canSave() {
		// TODO Auto-generated method stub
		return true;
	}

	public void deactivated(ILaunchConfigurationWorkingCopy arg0) {
		// TODO Auto-generated method stub

	}

	public void dispose() {
		// TODO Auto-generated method stub

	}

	public String getErrorMessage() {
		// TODO Auto-generated method stub
		return null;
	}

	public String getMessage() {
		// TODO Auto-generated method stub
		return null;
	}

	public String getName() {
		// TODO Auto-generated method stub
		return null;
	}

	public void initializeFrom(ILaunchConfiguration arg0) {
		// TODO Auto-generated method stub

	}

	public boolean isValid(ILaunchConfiguration arg0) {
		// TODO Auto-generated method stub
		return true;
	}

	public void launched(ILaunch arg0) {
		// TODO Auto-generated method stub

	}

	public void performApply(ILaunchConfigurationWorkingCopy arg0) {
		// TODO Auto-generated method stub

	}

	public void setDefaults(ILaunchConfigurationWorkingCopy arg0) {
		// TODO Auto-generated method stub

	}

	public void setLaunchConfigurationDialog(ILaunchConfigurationDialog arg0) {
		// TODO Auto-generated method stub

	}

	public void createControl(Composite arg0) {
		// TODO Auto-generated method stub
		
	}

	public Control getControl() {
		// TODO Auto-generated method stub
		return null;
	}

	public Image getImage() {
		// TODO Auto-generated method stub
		return null;
	}

}
