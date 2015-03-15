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


import javax.swing.*;
import java.awt.*;
import java.util.*;
import java.awt.event.*;

class TraceView extends JPanel
{
	TraceView(TraceModel model)
	{
		fModel = model;
		setPreferredSize(new Dimension(kEventWidth * fModel.getNumEvents(),
			kRowHeight * fModel.getNumRows()));
	}

	private int kEventWidth = 3;
	private int kRowHeight = 40;

	protected void paintComponent(Graphics g)
	{
		super.paintComponent(g);

		Rectangle visibleRect = getVisibleRect();
		int firstEvent = visibleRect.x / kEventWidth;
		int lastEvent = visibleRect.x + visibleRect.width / kEventWidth + 1;
		
		for (int event = firstEvent; event < lastEvent; event++)
		{
			boolean idle = true;
			for (int row = 0; row < fModel.getNumRows(); row++)
			{
				int value = fModel.getEvent(row, event);
				if (value == 4)
					idle = false;
				
				g.setColor(fEventColors[value]);
				g.fillRect(event * kEventWidth, row * kRowHeight, kEventWidth - 1, kRowHeight - 2);
			}
			
			if (!idle)
			{
				int y = kRowHeight * fModel.getNumRows() + 1;
				g.setColor(Color.blue);
				g.fillRect(event * kEventWidth, y, kEventWidth, 5);
			}
		}
	}
	
	private TraceModel fModel;
	private Color[] fEventColors = {
		Color.black,
		Color.red,
		Color.yellow,
		Color.orange,
		Color.green
	};
}

