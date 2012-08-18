// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

package asmbuilder;

//
// I configured this as a builder for a project by manually adding the following to the .project file:
//
// <buildSpec>
// <buildCommand>
//         <name>asmbuilder.Builder</name>
//         <triggers>full,incremental,</triggers>
// </buildCommand>
// </buildSpec>
//
// Eventually there should be a nature and plugin wizard or something.
//

import java.util.Map;

import org.eclipse.core.resources.IMarker;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.resources.IncrementalProjectBuilder;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.Status;
import org.eclipse.debug.core.model.IBreakpoint;
import org.eclipse.jface.dialogs.MessageDialog;
import org.eclipse.swt.widgets.Display;

import java.io.IOException;
import java.io.InputStream;

public class Builder extends IncrementalProjectBuilder
{
	protected IProject[] build(int arg0, Map<String, String> arguments,
			IProgressMonitor arg2) throws CoreException
	{
		String pathToAssembler = arguments.get("assemblerpath");
		if (pathToAssembler == null)
			 throw new CoreException(new Status(Status.OK, "emulatordebug.EmulatorDebugModel", "Assembler path not set"));

		IProject project = getProject();
		project.deleteMarkers(IMarker.PROBLEM, true, IResource.DEPTH_INFINITE);

		//  Build file argument list.
		StringBuffer args = new StringBuffer();
		for (IResource resource : project.members())
		{
			if (resource.getLocation().getFileExtension().equals("asm"))
			{
				args.append(" ");
				args.append(resource.getProjectRelativePath().toString());
			}
		}

		// Run the assembler and parse errors
		String executableName = project.getName() + ".hex";
		Process process;
		try
		{
			process = Runtime.getRuntime().exec(pathToAssembler + " -o " + executableName + " " + args.toString(), 
				null, project.getLocation().toFile());
			InputStream errorStream = process.getErrorStream();
	
			StringBuffer line = new StringBuffer();
readloop:	while (true)
			{
				line.setLength(0);
lineloop:		while (true)
				{
					int c = errorStream.read();
					if (c < 0)
						break readloop;
					else if (c == '\n')
						break lineloop;
					
					line.append((char) c);
				}

				System.out.println(line.toString());
				if (line.length() == 0)
					continue;
				
				// Parse the result, which is of the form 'file:line: error:'
				String s = line.toString();
				int colon1 = s.indexOf(':');
				if (colon1 != -1)
				{
					String path = s.substring(0, colon1);
					int colon2 = s.indexOf(':', colon1 + 1);
					if (colon2 != -1)
					{
						String lineNumStr = s.substring(colon1 + 1, colon2);
						IResource errorFile = project.findMember(path);
						if (errorFile == null)
							System.out.println("error finding member \"" + path + "\"");
						else
						{
							IMarker marker = errorFile.createMarker(IMarker.PROBLEM);	// marker type from <breakpoint> tag in plugin.xml, 
							marker.setAttribute(IMarker.LINE_NUMBER, Integer.parseInt(lineNumStr));
							marker.setAttribute(IMarker.SEVERITY, IMarker.SEVERITY_ERROR);
							marker.setAttribute(IMarker.MESSAGE, line.substring(colon2 + 1));	
						}
					}
				}
			}
		}
		catch (IOException e)
		{
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		return null;
	}

}
