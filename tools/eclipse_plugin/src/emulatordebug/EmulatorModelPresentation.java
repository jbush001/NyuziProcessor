package emulatordebug;

import org.eclipse.core.resources.IFile;
import org.eclipse.debug.core.model.IValue;
import org.eclipse.debug.ui.IDebugModelPresentation;
import org.eclipse.debug.ui.IValueDetailListener;
import org.eclipse.jface.viewers.ILabelProviderListener;
import org.eclipse.swt.graphics.Image;
import org.eclipse.ui.IEditorInput;
import org.eclipse.ui.part.FileEditorInput;

public class EmulatorModelPresentation implements IDebugModelPresentation
{

	public IEditorInput getEditorInput(Object element)
	{
		if (element instanceof IFile)
			return new FileEditorInput((IFile) element);

		return null;
	}

	public String getEditorId(IEditorInput input, Object element)
	{
		if (element instanceof IFile)
			return "org.eclipse.ui.DefaultTextEditor";

		return null;
	}

	@Override
	public void addListener(ILabelProviderListener arg0)
	{
		// TODO Auto-generated method stub

	}

	@Override
	public void dispose()
	{
		// TODO Auto-generated method stub

	}

	@Override
	public boolean isLabelProperty(Object arg0, String arg1)
	{
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public void removeListener(ILabelProviderListener arg0)
	{
		// TODO Auto-generated method stub

	}

	@Override
	public void computeDetail(IValue arg0, IValueDetailListener arg1)
	{
		// TODO Auto-generated method stub

	}

	@Override
	public Image getImage(Object arg0)
	{
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public String getText(Object arg0)
	{
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public void setAttribute(String arg0, Object arg1)
	{
		// TODO Auto-generated method stub

	}

}
