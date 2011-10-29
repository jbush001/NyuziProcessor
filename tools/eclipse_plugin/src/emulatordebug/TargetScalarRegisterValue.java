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
