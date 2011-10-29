package emulatordebug;

import org.eclipse.core.resources.IResource;
import org.eclipse.core.runtime.IAdapterFactory;
import org.eclipse.ui.texteditor.ITextEditor;

public class BreakpointAdapterFactory implements IAdapterFactory
{
	public BreakpointAdapterFactory()
	{
	}
	
	public Object getAdapter(Object adaptableObject, Class adapterType)
	{
		if (adaptableObject instanceof ITextEditor) {
			ITextEditor editorPart = (ITextEditor) adaptableObject;
			IResource resource = (IResource) editorPart.getEditorInput().getAdapter(IResource.class);
			if (resource != null) 
			{
				return new EmulatorLineBreakpointAdapter();
			}
		}

		return null;	
	}

	public Class[] getAdapterList()
	{
		return null;
	}

}
