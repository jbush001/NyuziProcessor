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
