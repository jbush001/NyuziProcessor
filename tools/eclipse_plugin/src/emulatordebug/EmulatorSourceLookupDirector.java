package emulatordebug;

import org.eclipse.debug.core.sourcelookup.AbstractSourceLookupDirector;
import org.eclipse.debug.core.sourcelookup.ISourceLookupParticipant;

public class EmulatorSourceLookupDirector extends AbstractSourceLookupDirector
{
	public void initializeParticipants()
	{
		addParticipants(new ISourceLookupParticipant[] { new EmulatorSourceLookupParticipant() });
	}
}
