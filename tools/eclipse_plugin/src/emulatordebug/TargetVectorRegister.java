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

import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.model.IRegister;
import org.eclipse.debug.core.model.IRegisterGroup;
import org.eclipse.debug.core.model.IValue;

public class TargetVectorRegister extends EmulatorDebugElement implements IRegister
{
	public TargetVectorRegister(EmulatorDebugTarget target, TargetRegisterGroup group, int registerIndex,
		String format)
	{
		super(target);
		fRegisterIndex = registerIndex;
		fRegisterGroup = group;
		fFormat = format;
	}

	public String getName() throws DebugException
	{
		return "v" + fRegisterIndex;
	}

	public String getReferenceTypeName() throws DebugException
	{
		return "integer";	// XXX not sure what this is for
	}

	public IValue getValue() throws DebugException
	{
		return new TargetVectorRegisterValue(getEmulatorDebugTarget(), getEmulatorDebugTarget()
			.getVectorRegisterValue(fRegisterIndex), fFormat);
	}

	public boolean hasValueChanged() throws DebugException
	{
		// XXX need to keep track of lower level changes
		return false;
	}

	public void setValue(String arg0) throws DebugException
	{
	}

	public void setValue(IValue arg0) throws DebugException
	{
	}

	public boolean supportsValueModification()
	{
		return false;
	}

	public boolean verifyValue(String arg0) throws DebugException
	{
		return false;
	}

	public boolean verifyValue(IValue arg0) throws DebugException
	{
		return false;
	}

	public IRegisterGroup getRegisterGroup() throws DebugException
	{
		return fRegisterGroup;
	}
	
	private int fRegisterIndex;
	private String fFormat;
	private TargetRegisterGroup fRegisterGroup;
	private TargetVectorRegisterValue fValue;
}
