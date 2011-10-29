package emulatordebug;

import org.eclipse.debug.core.ILaunch;
import org.eclipse.debug.core.model.IDebugElement;
import org.eclipse.debug.core.model.IDebugTarget;
import org.eclipse.debug.core.model.DebugElement;

// XXX should this derive from ?
public class EmulatorDebugElement extends DebugElement implements IDebugElement {

	EmulatorDebugElement(EmulatorDebugTarget target)
	{
		super(target);
		fTarget = target;
	}
	
	public Object getAdapter(Class adapter) 
	{
		if (adapter == IDebugElement.class)
			return this;
	
		return super.getAdapter(adapter);
	}

	public IDebugTarget getDebugTarget() 
	{
		return fTarget;
	}
	
	// Same as above, except casts.
	public EmulatorDebugTarget getEmulatorDebugTarget()
	{
		return fTarget;
	}

	public ILaunch getLaunch() 
	{
		return getDebugTarget().getLaunch();
	}

	public String getModelIdentifier() 
	{
		return "emulatordebug.EmulatorDebugModel";
	}
	
	EmulatorDebugTarget fTarget;
}
