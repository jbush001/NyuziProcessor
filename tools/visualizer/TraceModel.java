// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 

import java.io.*;

//
// Stores trace information.
// XXX this could be smarter about storing data in runs and using a binary 
// search to find ranges for display.
//

class TraceModel
{
	public TraceModel(String filename)
	{
		readFile(filename);
	}

	public int getNumEvents()
	{
		return fNumEvents;
	}
	
	public int getNumRows()
	{
		return fNumRows;
	}
	
	public int getEvent(int row, int eventIndex)
	{
		return fRawData[eventIndex * fNumRows + row];
	}
	
	private static final int kMaxLines = 0x100000;
	
	private void readFile(String filename)
	{
		fNumEvents = 0;
		fNumRows = 4;	// Number of threads XXX should determine dynamically
		fRawData = new byte[kMaxLines * fNumRows];
		int offset = 0;
		try
		{
			FileInputStream fstream = new FileInputStream(filename);
			DataInputStream in = new DataInputStream(fstream);
			BufferedReader br = new BufferedReader(new InputStreamReader(in));
			String line;
			for (fNumEvents = 0; fNumEvents < kMaxLines; fNumEvents++)
			{
				String eventLine = br.readLine();
				if (eventLine == null)
					break;
			
				String[] tokens = eventLine.split(",");
				for (int rowIndex = 0; rowIndex < fNumRows; rowIndex++)
				{
					// The constant values we are assigning here correspond
					// to colors in the array in TraceView.java.
					fRawData[offset++] = (byte) Integer.parseInt(tokens[rowIndex]);
				}
			}
			
			System.out.println("read " + fNumEvents + " events");
		}
		catch (Exception exc)
		{
			System.out.println("Caught exception " + exc);	
			exc.printStackTrace();
		}
	}

	private byte[] fRawData;
	private int fNumEvents;
	private int fNumRows;
}
