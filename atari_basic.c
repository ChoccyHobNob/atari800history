#include "atari.h"
#include "monitor.h"

static char *rcsid = "$Id: atari_basic.c,v 1.6 1998/02/21 14:54:11 david Exp $";

#define FALSE 0
#define TRUE 1

int Atari_Initialise(int *argc, char *argv[])
{
}

int Atari_Exit(int run_monitor)
{
	int restart;

	if (run_monitor)
		restart = monitor();
	else
		restart = FALSE;

	return restart;
}

int Atari_Keyboard(void)
{
	return AKEY_NONE;
}

int Atari_PORT(int num)
{
	return 0xff;
}

int Atari_TRIG(int num)
{
	return 1;
}

int Atari_POT(int num)
{
	return 228;
}

int Atari_CONSOL(void)
{
	return 7;
}
