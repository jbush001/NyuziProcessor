package emulatordebug;

import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.model.IValue;
import org.eclipse.debug.core.model.IVariable;

public class TargetVectorArrayElement extends EmulatorDebugElement implements
		IVariable
{
	public TargetVectorArrayElement(EmulatorDebugTarget target, int value, String format)
	{
		super(target);
		fValue = new TargetScalarRegisterValue(target, value, format);
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
		// XXX not sure how we can hit this code path
		return false;
	}

	public String getName() throws DebugException
	{
		return "[" + fLane + "]";	// XXX use array index
	}

	public String getReferenceTypeName() throws DebugException
	{
		// TODO Auto-generated method stub
		return "integer";
	}

	public IValue getValue() throws DebugException
	{
		return fValue;	// XXX return proper value
	}

	public boolean hasValueChanged() throws DebugException
	{
		// TODO Auto-generated method stub
		return false;
	}
	
	private int fLane;
	private TargetScalarRegisterValue fValue;
}
