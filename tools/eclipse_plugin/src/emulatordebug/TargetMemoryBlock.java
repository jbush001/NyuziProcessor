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
