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

