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
import org.eclipse.debug.core.model.IValue;
import org.eclipse.debug.core.model.IVariable;

public class TargetScalarRegisterValue extends EmulatorDebugElement implements IValue
{

	public TargetScalarRegisterValue(EmulatorDebugTarget target, int value, String format)
	{
		super(target);
		fValue = value;
		fFormat = format;
	}
	
	public String getReferenceTypeName() throws DebugException
	{
		return "integer";
	}

	public String getValueString() throws DebugException
	{
		if (fFormat.equals("f"))
			return Float.toString(Float.intBitsToFloat(fValue));
		else
			return Integer.toHexString(fValue);
	}

	public IVariable[] getVariables() throws DebugException
	{
		return null;
	}

	public boolean hasVariables() throws DebugException
	{
		return false;
	}

	public boolean isAllocated() throws DebugException
	{
		// TODO Auto-generated method stub
		return false;
	}
	
	private int fValue;
	private String fFormat;
}
