

class DebugPrinter
{
public:
	DebugPrinter &operator<<(const char *str)
	{
		for (const char *c = str; *c; c++)
			writeChar(*c);
			
		return *this;
	}

	DebugPrinter &operator<<(unsigned int value)
	{
		writeChar('0');
		writeChar('x');
		for (int i = 0; i < 8; i++)
		{
			int digitValue = value >> (i * 4);
			if (digitValue < 10)
				writeChar(digitValue + '0');
			else 
				writeChar(digitValue + 'A');
		}
		
		return *this;
	}

private:
	void writeChar(char c)
	{
		*((unsigned*) 0xFFFF0004) = c;
	}
};

DebugPrinter debug;

int main()
{
	debug << "Hello World: " << 0x12345678 << "\n";
	
	return 0;
}
