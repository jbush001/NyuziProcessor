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

import org.eclipse.debug.core.DebugEvent;
import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.model.IMemoryBlock;

public class TargetMemoryBlock extends EmulatorDebugElement implements
		IMemoryBlock
{
	public TargetMemoryBlock(EmulatorDebugTarget target, long startAddress, long length)
	{
		super(target);
		fStartAddress = startAddress;
		fBytes = new byte[(int) length];
	}
	
	// Called by the memory fetch callback to update display.
	void setBytes(byte[] bytes)
	{
		assert(fBytes.length == bytes.length);
		fBytes = bytes;
		fireChangeEvent(DebugEvent.CONTENT);
	}

	public byte[] getBytes() throws DebugException
	{
		return fBytes;
	}

	public long getLength()
	{
		return fBytes.length;
	}

	public long getStartAddress()
	{
		return fStartAddress;
	}

	public void setValue(long arg0, byte[] arg1) throws DebugException
	{
		// TODO Auto-generated method stub
	}

	public boolean supportsValueModification()
	{
		// TODO Auto-generated method stub
		return false;
	}

	private long fStartAddress;
	private byte[] fBytes;
}
