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
