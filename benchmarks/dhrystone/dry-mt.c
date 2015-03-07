/***** hpda:net.sources / homxb!gemini /  1:58 am  Apr  1, 1986*/
/*	
 *	"DHRYSTONE" Benchmark Program
 *
 *	Version:	C/1.1, 12/01/84
 *
 *	Date:		PROGRAM updated 01/06/86, RESULTS updated 03/31/86
 *
 *	Author:		Reinhold P. Weicker,  CACM Vol 27, No 10, 10/84 pg. 1013
 *			Translated from ADA by Rick Richardson
 *			Every method to preserve ADA-likeness has been used,
 *			at the expense of C-ness.
 *			Modified by Jeff Bush to support multiple threads
 */

#define NUM_THREADS 4
#define LOOPS	5000	

char	Version[] = "1.1";

#define	structassign(d, s)	d = s

typedef enum	{Ident1, Ident2, Ident3, Ident4, Ident5} Enumeration;

typedef int	OneToThirty;
typedef int	OneToFifty;
typedef char	CapitalLetter;
typedef char	String30[31];
typedef int	Array1Dim[51];
typedef int	Array2Dim[51][51];

typedef struct Record 	RecordType;
typedef RecordType *	RecordPtr;
typedef int		boolean;

#define	NULL		0
#define	TRUE		1
#define	FALSE		0

#define	REG

struct	Record
{
	struct Record		*PtrComp;
	Enumeration		Discr;
	Enumeration		EnumComp;
	OneToFifty		IntComp;
	String30		StringComp;
};

struct Globals
{
	int		IntGlob;
	boolean		BoolGlob;
	char		Char1Glob;
	char		Char2Glob;
	Array1Dim	Array1Glob;
	Array2Dim	Array2Glob;
	RecordPtr	PtrGlb;
	RecordPtr	PtrGlbNext;
};



extern Enumeration	Func1();
extern boolean		Func2();

// All threads start execution here
main()
{
	struct Globals Glob;
	
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);	// Start other threads
	Proc0(&Glob);
}

/*
 * Package 1
 */


Proc0(Globs)
struct Globals *Globs;
{
	OneToFifty		IntLoc1;
	REG OneToFifty		IntLoc2;
	OneToFifty		IntLoc3;
	REG char		CharLoc;
	REG char		CharIndex;
	Enumeration	 	EnumLoc;
	String30		String1Loc;
	String30		String2Loc;
	int             starttime;
	int             benchtime;
	extern char		*malloc();

	register unsigned int	i;

	Globs->PtrGlbNext = (RecordPtr) malloc(sizeof(RecordType));
	Globs->PtrGlb = (RecordPtr) malloc(sizeof(RecordType));
	Globs->PtrGlb->PtrComp = Globs->PtrGlbNext;
	Globs->PtrGlb->Discr = Ident1;
	Globs->PtrGlb->EnumComp = Ident3;
	Globs->PtrGlb->IntComp = 40;
	strcpy(Globs->PtrGlb->StringComp, "DHRYSTONE PROGRAM, SOME STRING");
	strcpy(String1Loc, "DHRYSTONE PROGRAM, 1'ST STRING");
	Globs->Array2Glob[8][7] = 10;

/*****************
-- Start Timer --
*****************/
	for (i = 0; i < LOOPS / NUM_THREADS; ++i)
	{

		Proc5(&Globs);
		Proc4(&Globs);
		IntLoc1 = 2;
		IntLoc2 = 3;
		strcpy(String2Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
		EnumLoc = Ident2;
		Globs->BoolGlob = ! Func2(String1Loc, String2Loc);
		while (IntLoc1 < IntLoc2)
		{
			IntLoc3 = 5 * IntLoc1 - IntLoc2;
			Proc7(IntLoc1, IntLoc2, &IntLoc3);
			++IntLoc1;
		}
		Proc8(Globs, Globs->Array1Glob, Globs->Array2Glob, IntLoc1, IntLoc3);
		Proc1(Globs, Globs->PtrGlb);
		for (CharIndex = 'A'; CharIndex <= Globs->Char2Glob; ++CharIndex)
			if (EnumLoc == Func1(CharIndex, 'C'))
				Proc6(&Globs, Ident1, &EnumLoc);
		IntLoc3 = IntLoc2 * IntLoc1;
		IntLoc2 = IntLoc3 / IntLoc1;
		IntLoc2 = 7 * (IntLoc3 - IntLoc2) - IntLoc1;
		Proc2(Globs, &IntLoc1);
	}

/*****************
-- Stop Timer --
*****************/
}

Proc1(Globs, PtrParIn)
struct Globals *Globs;
REG RecordPtr	PtrParIn;
{
#define	NextRecord	(*(PtrParIn->PtrComp))

	structassign(NextRecord, *Globs->PtrGlb);
	PtrParIn->IntComp = 5;
	NextRecord.IntComp = PtrParIn->IntComp;
	NextRecord.PtrComp = PtrParIn->PtrComp;
	Proc3(Globs, NextRecord.PtrComp);
	if (NextRecord.Discr == Ident1)
	{
		NextRecord.IntComp = 6;
		Proc6(Globs, PtrParIn->EnumComp, &NextRecord.EnumComp);
		NextRecord.PtrComp = Globs->PtrGlb->PtrComp;
		Proc7(NextRecord.IntComp, 10, &NextRecord.IntComp);
	}
	else
		structassign(*PtrParIn, NextRecord);

#undef	NextRecord
}

Proc2(Globs, IntParIO)
struct Globals *Globs;
OneToFifty	*IntParIO;
{
	REG OneToFifty		IntLoc;
	REG Enumeration		EnumLoc;

	IntLoc = *IntParIO + 10;
	for(;;)
	{
		if (Globs->Char1Glob == 'A')
		{
			--IntLoc;
			*IntParIO = IntLoc - Globs->IntGlob;
			EnumLoc = Ident1;
		}
		if (EnumLoc == Ident1)
			break;
	}
}

Proc3(Globs, PtrParOut)
struct Globals *Globs;
RecordPtr	*PtrParOut;
{
	if (Globs->PtrGlb != NULL)
		*PtrParOut = Globs->PtrGlb->PtrComp;
	else
		Globs->IntGlob = 100;
	Proc7(10, Globs->IntGlob, &Globs->PtrGlb->IntComp);
}

Proc4(Globs)
struct Globals *Globs;
{
	REG boolean	BoolLoc;

	BoolLoc = Globs->Char1Glob == 'A';
	BoolLoc |= Globs->BoolGlob;
	Globs->Char2Glob = 'B';
}

Proc5(Globs)
struct Globals *Globs;
{
	Globs->Char1Glob = 'A';
	Globs->BoolGlob = FALSE;
}

extern boolean Func3();

Proc6(Globs, EnumParIn, EnumParOut)
struct Globals *Globs;
REG Enumeration	EnumParIn;
REG Enumeration	*EnumParOut;
{
	*EnumParOut = EnumParIn;
	if (! Func3(EnumParIn) )
		*EnumParOut = Ident4;
	switch (EnumParIn)
	{
	case Ident1:	*EnumParOut = Ident1; break;
	case Ident2:	if (Globs->IntGlob > 100) *EnumParOut = Ident1;
			else *EnumParOut = Ident4;
			break;
	case Ident3:	*EnumParOut = Ident2; break;
	case Ident4:	break;
	case Ident5:	*EnumParOut = Ident3;
	}
}

Proc7(IntParI1, IntParI2, IntParOut)
OneToFifty	IntParI1;
OneToFifty	IntParI2;
OneToFifty	*IntParOut;
{
	REG OneToFifty	IntLoc;

	IntLoc = IntParI1 + 2;
	*IntParOut = IntParI2 + IntLoc;
}

Proc8(Globs, Array1Par, Array2Par, IntParI1, IntParI2)
struct Globals *Globs;
Array1Dim	Array1Par;
Array2Dim	Array2Par;
OneToFifty	IntParI1;
OneToFifty	IntParI2;
{
	REG OneToFifty	IntLoc;
	REG OneToFifty	IntIndex;

	IntLoc = IntParI1 + 5;
	Array1Par[IntLoc] = IntParI2;
	Array1Par[IntLoc+1] = Array1Par[IntLoc];
	Array1Par[IntLoc+30] = IntLoc;
	for (IntIndex = IntLoc; IntIndex <= (IntLoc+1); ++IntIndex)
		Array2Par[IntLoc][IntIndex] = IntLoc;
	++Array2Par[IntLoc][IntLoc-1];
	Array2Par[IntLoc+20][IntLoc] = Array1Par[IntLoc];
	Globs->IntGlob = 5;
}

Enumeration Func1(CharPar1, CharPar2)
CapitalLetter	CharPar1;
CapitalLetter	CharPar2;
{
	REG CapitalLetter	CharLoc1;
	REG CapitalLetter	CharLoc2;

	CharLoc1 = CharPar1;
	CharLoc2 = CharLoc1;
	if (CharLoc2 != CharPar2)
		return (Ident1);
	else
		return (Ident2);
}

boolean Func2(StrParI1, StrParI2)
String30	StrParI1;
String30	StrParI2;
{
	REG OneToThirty		IntLoc;
	REG CapitalLetter	CharLoc;

	IntLoc = 1;
	while (IntLoc <= 1)
		if (Func1(StrParI1[IntLoc], StrParI2[IntLoc+1]) == Ident1)
		{
			CharLoc = 'A';
			++IntLoc;
		}
	if (CharLoc >= 'W' && CharLoc <= 'Z')
		IntLoc = 7;
	if (CharLoc == 'X')
		return(TRUE);
	else
	{
		if (strcmp(StrParI1, StrParI2) > 0)
		{
			IntLoc += 7;
			return (TRUE);
		}
		else
			return (FALSE);
	}
}

boolean Func3(EnumParIn)
REG Enumeration	EnumParIn;
{
	REG Enumeration	EnumLoc;

	EnumLoc = EnumParIn;
	if (EnumLoc == Ident3) return (TRUE);
	return (FALSE);
}
