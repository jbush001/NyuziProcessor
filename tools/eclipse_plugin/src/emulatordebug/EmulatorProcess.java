package emulatordebug;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.io.InputStream;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.Queue;
import java.util.StringTokenizer;

//
// Wraps the emulator process, spawning the executable and communicating with it.
//
public class EmulatorProcess
{
	static final String kPathToInterpreter = "/Users/jeffbush/src/gpu/tools/emulator/emulator";

	public abstract class Callback
	{
		abstract void invoke(String[] result);
	}
	
	public EmulatorProcess()
	{
	}
	
	public void connect(String executableName, File workingDirectory)
	{
		try
		{
			// XXX Need to find a way to get the working directly programmatically from the project.
			fRemoteProcess = Runtime.getRuntime().exec(kPathToInterpreter + " " + executableName, null,
					workingDirectory);	// XXX make this a parameter
		}
		catch (IOException e)
		{
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		fOutputStream = fRemoteProcess.getOutputStream();
		fInputStream = fRemoteProcess.getInputStream();

		(new Thread(new Runnable() { public void run() { inputLoop(); } })).start();
	}
	
	public void disconnect()
	{
		fRemoteProcess.destroy();
	}
	
	public void registerUnsolicitedCallback(String type, Callback callback)
	{
		fUnsolicitedMap.put(type, callback);
	}
	
	private void inputLoop()
	{
		try
		{
			StringBuffer line = new StringBuffer();
			while (true)
			{
				line.setLength(0);
				while (true)
				{
					int c = fInputStream.read();
					if (c == '\n')
						break;
					
					line.append((char) c);
				}

				System.out.println("RECV: " + line.toString());
				if (line.length() == 0)
					continue;

				if (line.charAt(0) == '*')
				{
					// Debugging comment, ignore
				}
				else if (line.charAt(0) == '!')
				{
					// Unsolicited response (usually a breakpoint notification)
					StringTokenizer tokenizer = new StringTokenizer(line.toString());
					int tokenCount = tokenizer.countTokens();
					String[] result = new String[tokenCount - 1];
					String type = tokenizer.nextToken().substring(1);
					for (int i = 0; i < tokenCount - 1; i++)
						result[i] = tokenizer.nextToken();

					Callback callback = fUnsolicitedMap.get(type);
					if (callback != null)
						callback.invoke(result);
				}
				else
				{
					// Tokenize the result
					StringTokenizer tokenizer = new StringTokenizer(line.toString());
					int tokenCount = tokenizer.countTokens();
					String[] result = new String[tokenCount];
					for (int i = 0; i < tokenCount; i++)
						result[i] = tokenizer.nextToken();

					Callback callback;
					synchronized (fCommandQueue)
					{
						callback = fCommandQueue.remove();
					}

					// XXX note: ensure we are not holding the monitor lock when this is called to avoid a deadlock.
					if (callback != null)
						callback.invoke(result);
				}
			}
		}
		catch (IOException e)
		{
			e.printStackTrace();
		}
	}
	
	public void sendCommand(String cmd, Callback callback) 
	{
		synchronized (fCommandQueue)
		{
			fCommandQueue.add(callback);
		}
		
		try
		{
			System.out.println("SEND: " + cmd);
			fOutputStream.write((cmd + "\n").getBytes());
			fOutputStream.flush();
		}
		catch (IOException e)
		{
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}
	
	private HashMap<String, Callback> fUnsolicitedMap = new HashMap<String, Callback>();
	private Queue<Callback> fCommandQueue = new LinkedList<Callback>();
	private Process fRemoteProcess;
	private OutputStream fOutputStream;	
	private InputStream fInputStream;
}
