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

public class TargetScalarRegister extends EmulatorDebugElement implements IRegister
{
	public TargetScalarRegister(EmulatorDebugTarget target, TargetRegisterGroup group, 
		int registerIndex, String format)
	{
		super(target);
		fFormat = format;
		fRegisterIndex = registerIndex;
		fRegisterGroup = group;
	}

	public String getName() throws DebugException
	{
		return "s" + fRegisterIndex;
	}

	public String getReferenceTypeName() throws DebugException
	{
		return "integer";
	}

	public IValue getValue() throws DebugException
	{
		return new TargetScalarRegisterValue(getEmulatorDebugTarget(), getEmulatorDebugTarget()
				.getScalarRegisterValue(fRegisterIndex), fFormat);
	}

	public boolean hasValueChanged() throws DebugException
	{
		// XXX need to keep track of lower level changes
		return false;
	}

	public void setValue(String str) throws DebugException
	{
	}

	public void setValue(IValue arg0) throws DebugException
	{
	}

	public boolean supportsValueModification()
	{
		return false;
	}

	public boolean verifyValue(String str) throws DebugException
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
	
	private String fFormat;
	private int fRegisterIndex;
	private TargetRegisterGroup fRegisterGroup;
}
