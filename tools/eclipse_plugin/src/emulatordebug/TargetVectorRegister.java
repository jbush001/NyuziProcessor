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
