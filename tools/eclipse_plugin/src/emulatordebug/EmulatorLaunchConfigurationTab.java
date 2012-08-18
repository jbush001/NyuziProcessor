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
