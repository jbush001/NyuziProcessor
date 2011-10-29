package emulatordebug;

import org.eclipse.debug.core.DebugException;
import org.eclipse.debug.core.model.IRegister;
import org.eclipse.debug.core.model.IRegisterGroup;

public class TargetRegisterGroup extends EmulatorDebugElement implements
		IRegisterGroup
{
	// Width is s or v
	// format is f or i
	public TargetRegisterGroup(EmulatorDebugTarget target, String width, String format)
	{
		super(target);
		fWidth = width;
		fFormat = format;
		for (int i = 0; i < 32; i++)
		{
			if (width == "v")
				fRegisters[i] = new TargetVectorRegister(target, this, i, format);
			else
				fRegisters[i] = new TargetScalarRegister(target, this, i, format);
		}
	}

	public String getName() throws DebugException
	{
		String name = "";
		
		if (fWidth == "v")
			name = "Vector";
		else
			name = "Scalar";
		
		if (fFormat == "f")
			name += " FP";
		else
			name += " Int";
		
		return name;
	}

	public IRegister[] getRegisters() throws DebugException
	{
		return fRegisters;
	}

	public boolean hasRegisters() throws DebugException
	{
		return true;
	}
	
	private IRegister[] fRegisters = new IRegister[32];
	private String fWidth;
	private String fFormat;
}
