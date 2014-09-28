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
import java.awt.event.*;
import java.util.*;
import javax.swing.text.*;
import java.io.*;

//
// Given a flat text file that contains thread states x x x x, outputted from the
// Verilog simulation model for each cycle, display a color bar chart of the states.
//

class VisualizerApp extends JPanel
{
	public VisualizerApp(String filename)
	{
		super(new BorderLayout());
		TraceModel model = new TraceModel(filename);
		JScrollPane scrollPane = new JScrollPane(new TraceView(model));
		add(scrollPane, BorderLayout.CENTER);
		setPreferredSize(new Dimension(900,300));
	}
	
	private static void createAndShowGUI(String[] args)
	{
		final VisualizerApp contentPane = new VisualizerApp(args[0]);
		JFrame frame = new JFrame("Visualizer");
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		frame.setContentPane(contentPane);
		frame.pack();
		frame.setVisible(true);
	}

	public static void main(String[] args)
	{
		final String[] _args = args;
		javax.swing.SwingUtilities.invokeLater(new Runnable() { 
			public void run() { createAndShowGUI(_args); } 
		});
	}
}
