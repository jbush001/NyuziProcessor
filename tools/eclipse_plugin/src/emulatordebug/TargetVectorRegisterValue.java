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

import java.util.Formatter;

import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.model.IValue;
import org.eclipse.debug.core.model.IVariable;

public class TargetVectorRegisterValue extends EmulatorDebugElement implements IValue
{

	public TargetVectorRegisterValue(EmulatorDebugTarget target, int[] values, String format)
	{
		super(target);
		fValues = values;
		for (int lane = 0; lane < 16; lane++)
			fElements[lane] = new TargetVectorArrayElement(target, values[lane], format);
	}
	
	public String getReferenceTypeName() throws DebugException
	{
		return "integer";
	}

	public String getValueString() throws DebugException
	{
		String str = "";
		for (int lane = 0; lane < 16; lane++)
			str += fFormatter.format("%0$08x", fValues[lane]);
			
		return str;
	}

	// We also create sub-elements for the individual lanes of the vector
	public IVariable[] getVariables() throws DebugException
	{
		return fElements;
	}

	public boolean hasVariables() throws DebugException
	{
		return true;
	}

	public boolean isAllocated() throws DebugException
	{
		// TODO Auto-generated method stub
		return false;
	}

	private int[] fValues;
	private TargetVectorArrayElement[] fElements = new TargetVectorArrayElement[16];
	private Formatter fFormatter = new Formatter();
}
