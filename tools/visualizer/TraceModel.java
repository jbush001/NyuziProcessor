// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


import java.io.*;

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
		fNumRows = 4;
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
					boolean valid = Integer.parseInt(tokens[rowIndex * 2]) != 0;
					int state = Integer.parseInt(tokens[rowIndex * 2 + 1]);
					if (state <= 2)
					{
						if (valid)
							fRawData[offset++] = (byte) 3;	// Ready
						else
							fRawData[offset++] = (byte) 0;	// Wait for icache
					}
					else if (state == 3)
						fRawData[offset++] = (byte) 2;	// RAW wait
					else
						fRawData[offset++] = (byte) 1;	// dcache/stbuf wait
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
