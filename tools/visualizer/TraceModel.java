// 
// Copyright 2011-2015 Jeff Bush
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
