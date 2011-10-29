package emulatordebug;

import org.eclipse.core.runtime.CoreException;
import org.eclipse.debug.core.sourcelookup.AbstractSourceLookupParticipant;

public class EmulatorSourceLookupParticipant extends
		AbstractSourceLookupParticipant
{
	public String getSourceName(Object frame) throws CoreException
	{
		return ((TargetStackFrame) frame).getSourceName();
	}
}
