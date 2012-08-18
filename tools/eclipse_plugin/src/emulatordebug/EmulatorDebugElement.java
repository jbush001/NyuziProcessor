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
import org.eclipse.debug.core.model.IDebugElement;
import org.eclipse.debug.core.model.IDebugTarget;
import org.eclipse.debug.core.model.DebugElement;

// XXX should this derive from ?
public class EmulatorDebugElement extends DebugElement implements IDebugElement {

	EmulatorDebugElement(EmulatorDebugTarget target)
	{
		super(target);
		fTarget = target;
	}
	
	public Object getAdapter(Class adapter) 
	{
		if (adapter == IDebugElement.class)
			return this;
	
		return super.getAdapter(adapter);
	}

	public IDebugTarget getDebugTarget() 
	{
		return fTarget;
	}
	
	// Same as above, except casts.
	public EmulatorDebugTarget getEmulatorDebugTarget()
	{
		return fTarget;
	}

	public ILaunch getLaunch() 
	{
		return getDebugTarget().getLaunch();
	}

	public String getModelIdentifier() 
	{
		return "emulatordebug.EmulatorDebugModel";
	}
	
	EmulatorDebugTarget fTarget;
}
