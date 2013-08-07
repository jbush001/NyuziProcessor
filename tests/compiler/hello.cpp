
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
			int digitValue = value >> 28;
			value <<= 4;
			if (digitValue < 10)
				writeChar(digitValue + '0');
			else 
				writeChar(digitValue - 10 + 'A');
		}
		
		return *this;
	}

private:
	void writeChar(char c)
	{
		*((volatile unsigned int*) 0xFFFF0004) = c;
	}
};

DebugPrinter debug;

int main()
{
	debug << "Hello World: " << 0x1234abcd << ".\n";
	// CHECK: Hello World: 0x1234ABCD.
	
	return 0;
}
