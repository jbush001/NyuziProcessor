package emulatordebug;

import org.eclipse.core.resources.IMarker;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.debug.core.model.IBreakpoint;
import org.eclipse.debug.core.model.LineBreakpoint;

public class EmulatorLineBreakpoint extends LineBreakpoint
{
	public EmulatorLineBreakpoint()
	{
	}
	
	public EmulatorLineBreakpoint(IResource resource, int line)
	{
		IMarker marker;
		try
		{
			marker = resource.createMarker("emulatordebug.lineBreakpoint.marker");	// marker type from <breakpoint> tag in plugin.xml, 
			setMarker(marker);
			marker.setAttribute(IBreakpoint.ENABLED, Boolean.TRUE);
			marker.setAttribute(IMarker.LINE_NUMBER, line);
			marker.setAttribute(IBreakpoint.ID, getModelIdentifier());
			marker.setAttribute(IMarker.MESSAGE, "breakpoint " + line);	
		}
		catch (CoreException e)
		{
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	public String getModelIdentifier()
	{
		return "emulatordebug.EmulatorDebugModel";
	}
}
