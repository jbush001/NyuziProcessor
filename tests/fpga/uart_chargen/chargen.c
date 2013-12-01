
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
	
int main()
{
	for (;;)
	{
		for (int startIndex = 0; startIndex < kPatternLength; startIndex++)
		{
			int index = startIndex;
			for (int lineOffset = 0; lineOffset < kLineLength; lineOffset++)
			{
				while (UART_BASE[kStatus])	// Wait for ready
					;
				
				UART_BASE[kTx] = kPattern[index];	// write character
				if (++index == kPatternLength)
					index = 0;
			}
		}
	}
}
