
const char *kPattern = "!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz";
const int kPatternLength = 89;
const int kLineLength = 72;

volatile unsigned int * const UART_BASE = (volatile unsigned int*) 0xFFFF0018;
	
enum UartRegs
{
	kStatus = 0,
	kRx = 1,
	kTx = 2
};
	
void writeChar(char ch)	
{
	while ((UART_BASE[kStatus] & 1) == 0)	// Wait for ready
		;
	
	UART_BASE[kTx] = ch;
}

int main()
{
	for (;;)
	{
		for (int startIndex = 0; startIndex < kPatternLength; startIndex++)
		{
			int index = startIndex;
			for (int lineOffset = 0; lineOffset < kLineLength; lineOffset++)
			{
				writeChar(kPattern[index]);
				if (++index == kPatternLength)
					index = 0;
			}
			
			writeChar('\r');
			writeChar('\n');
		}
	}
}
