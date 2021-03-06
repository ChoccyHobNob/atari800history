#include <stdlib.h>
#ifdef VMS
#include <types.h>
#else
#include <sys/types.h>
#endif
#include <time.h>

#include "atari.h"
#include "cpu.h"
#include "pia.h"
#include "pokey.h"
#include "gtia.h"
#include "sio.h"
#include "platform.h"
#include "statesav.h"
#include "pokeysnd.h"

#ifdef SERIO_SOUND
void Update_serio_sound( int out, UBYTE data );
#endif

#ifdef POKEY_UPDATE
extern void pokey_update(void);
#endif

#ifndef NO_VOL_ONLY
void Update_vol_only_sound( void );
#endif  /* NO_VOL_ONLY */

#define FALSE 0
#define TRUE 1

UBYTE KBCODE;
UBYTE IRQST;
UBYTE IRQEN;
UBYTE SKSTAT;
int SHIFT_KEY = FALSE, KEYPRESSED = FALSE;
int DELAYED_SERIN_IRQ;
int DELAYED_SEROUT_IRQ;
int DELAYED_XMTDONE_IRQ;

/* structures to hold the 9 pokey control bytes */ 
UBYTE AUDF[8];    /* AUDFx (D200, D202, D204, D206) */
UBYTE AUDC[8];    /* AUDCx (D201, D203, D205, D207) */
UBYTE AUDCTL;     /* AUDCTL (D208) */   
int DivNIRQ[4], DivNMax[4];
int TimeBase = DIV_64;

#ifdef STEREO
int pokey_select;
int stereo_enabled = TRUE;
#endif

UBYTE POKEY_GetByte(UWORD addr)
{
	UBYTE byte = 0xff;
	static int rand_init = 0;

	addr &= 0x0f;
	switch (addr) {
	case _KBCODE:
		byte = KBCODE;
		break;
	case _IRQST:
		byte = IRQST;
#ifdef DEBUG1
		printf("RD: IRQST = %x, PC = %x\n", byte, PC);
#endif
		break;
	case _POT0:
		byte = Atari_POT(0);
		break;
	case _POT1:
		byte = Atari_POT(1);
		break;
	case _POT2:
		byte = Atari_POT(2);
		break;
	case _POT3:
		byte = Atari_POT(3);
		break;
	case _POT4:
		byte = Atari_POT(4);
		break;
	case _POT5:
		byte = Atari_POT(5);
		break;
	case _POT6:
		byte = Atari_POT(6);
		break;
	case _POT7:
		byte = Atari_POT(7);
		break;
	case _RANDOM:
		if (!rand_init) {
			srand((int) time((time_t *) NULL));
			rand_init = 1;
		}
		byte = rand();
		break;
	case _SERIN:
		/* byte = SIO_SERIN(); */
		byte = SIO_GetByte();
#ifdef DEBUG1
		printf("RD: SERIN = %x, BUFRFL = %x, CHKSUM = %x, BUFR = %02x%02x, BFEN=%02x%02x, PC = %x\n",
			byte, memory[0x38], memory[0x31], memory[0x33], memory[0x32],
			   memory[0x35], memory[0x34], PC);
		printf("AR RD: SERIN = %x, BUFRFL = %x, CHKSUM = %x, BUFR = %02x%02x, BFEN=%02x%02x, PC = %x\n",
			 byte, memory[0x38], memory[0x23c], memory[0x1], memory[0x0],
			   memory[0x23b], memory[0x23a], PC);
#endif
#ifdef SERIO_SOUND
			Update_serio_sound(0,byte);
#endif
		break;
	case _SKSTAT:
		byte = 0xff;
		if (SHIFT_KEY)
			byte &= ~8;
		if (KEYPRESSED)
			byte &= ~4;
		break;
	}

	return byte;
}

void Update_Counter(int chan_mask);

int POKEY_siocheck(void)
{
	return ((AUDF[CHAN3] == 0x28) && (AUDF[CHAN4] == 0x00) && (AUDCTL & 0x28) == 0x28);
}

#define SOUND_GAIN 4

void POKEY_PutByte(UWORD addr, UBYTE byte)
{
#ifdef STEREO
	pokey_select= ((addr>>4))&0x01;

#endif
	addr &= 0x0f;
	switch (addr) {
	case _AUDC1:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDC[CHAN1] = byte;
		Update_pokey_sound(1, byte, 0, SOUND_GAIN);
		break;
	case _AUDC2:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDC[CHAN2] = byte;
		Update_pokey_sound(3, byte, 0, SOUND_GAIN);
		break;
	case _AUDC3:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDC[CHAN3] = byte;
		Update_pokey_sound(5, byte, 0, SOUND_GAIN);
		break;
	case _AUDC4:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDC[CHAN4] = byte;
		Update_pokey_sound(7, byte, 0, SOUND_GAIN);
		break;
	case _AUDCTL:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDCTL = byte;

		/* determine the base multiplier for the 'div by n' calculations */
		if (AUDCTL & CLOCK_15)
			TimeBase = DIV_15;
		else
			TimeBase = DIV_64;

		Update_Counter((1 << CHAN1) | (1 << CHAN2) | (1 << CHAN3) | (1 << CHAN4));
		Update_pokey_sound(8, byte, 0, SOUND_GAIN);
		break;
	case _AUDF1:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDF[CHAN1] = byte;
		Update_Counter((AUDCTL & CH1_CH2) ? ((1 << CHAN2) | (1 << CHAN1)) : (1 << CHAN1));
		Update_pokey_sound(0, byte, 0, SOUND_GAIN);
		break;
	case _AUDF2:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDF[CHAN2] = byte;
		Update_Counter(1 << CHAN2);
		Update_pokey_sound(2, byte, 0, SOUND_GAIN);
		break;
	case _AUDF3:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDF[CHAN3] = byte;
		Update_Counter((AUDCTL & CH3_CH4) ? ((1 << CHAN4) | (1 << CHAN3)) : (1 << CHAN3));
		Update_pokey_sound(4, byte, 0, SOUND_GAIN);
		break;
	case _AUDF4:
#ifdef STEREO
		if( pokey_select==0 )
#endif
		AUDF[CHAN4] = byte;
		Update_Counter(1 << CHAN4);
		Update_pokey_sound(6, byte, 0, SOUND_GAIN);
		break;
	case _IRQEN:
		IRQEN = byte;
#ifdef DEBUG1
		printf("WR: IRQEN = %x, PC = %x\n", IRQEN, PC);
#endif
		IRQST |= ~byte & 0xf7;	/* Reset disabled IRQs except XMTDONE */
		if ((~IRQST & IRQEN) == 0)
			IRQ = 0;
		break;
	case _POTGO:
		break;
	case _SEROUT:
		if ((SKSTAT & 0x70) == 0x20) {
			if (POKEY_siocheck()) {
				SIO_PutByte(byte);
				IRQST |= 0x08;
				DELAYED_XMTDONE_IRQ = XMTDONE_INTERVAL;
#ifdef SERIO_SOUND
				Update_serio_sound(1,byte);
#endif
			}
		}
		break;
	case _STIMER:
		DivNIRQ[CHAN1] = DivNIRQ[CHAN2] = DivNIRQ[CHAN4] = 0;
#ifdef DEBUG1
		printf("WR: STIMER = %x\n", byte);
#endif
		break;
	case _SKSTAT:
		SKSTAT = byte;
		break;
	}
}

void POKEY_Initialise(int *argc, char *argv[])
{
	int i;

	/*
	 * Initialise Serial Port Interrupts
	 */

	DELAYED_SERIN_IRQ = 0;
	DELAYED_SEROUT_IRQ = 0;
	DELAYED_XMTDONE_IRQ = 0;

	AUDCTL = 0;
	IRQST = 0xff;
	IRQEN = 0x00;
	TimeBase = DIV_64;

	for (i = 0; i < 4; i++)
		DivNIRQ[i] = DivNMax[i] = 0;
}

/***************************************************************************
 ** Generate POKEY Timer IRQs if required                                 **
 ** called on a per-scanline basis, not very precise, but good enough     **
 ** for most applications                                                 **
 ***************************************************************************/

void POKEY_Scanline(void)
{
#ifdef POKEY_UPDATE
	pokey_update();
#endif

#ifndef NO_VOL_ONLY
	Update_vol_only_sound();
#endif  /* NO_VOL_ONLY */

	if (DELAYED_SERIN_IRQ > 0) {
		if (--DELAYED_SERIN_IRQ == 0) {
			if (IRQEN & 0x20) {
#ifdef DEBUG2
				printf("SERIO: SERIN Interrupt triggered\n");
#endif
				IRQST &= 0xdf;
				GenerateIRQ();
			}
#ifdef DEBUG2
			else {
				printf("SERIO: SERIN Interrupt missed\n");
			}
#endif
		}
	}

	if (DELAYED_SEROUT_IRQ > 0) {
		if (--DELAYED_SEROUT_IRQ == 0) {
			if (IRQEN & 0x10) {
#ifdef DEBUG2
				printf("SERIO: SEROUT Interrupt triggered\n");
#endif
				IRQST &= 0xef;
				GenerateIRQ();
			}
#ifdef DEBUG2
			else {
				printf("SERIO: SEROUT Interrupt missed\n");
			}
#endif
		}
	}

	if (DELAYED_XMTDONE_IRQ > 0)
		if (--DELAYED_XMTDONE_IRQ == 0) {
			IRQST &= 0xf7;
			if (IRQEN & 0x08) {
#ifdef DEBUG2
				printf("SERIO: XMTDONE Interrupt triggered\n");
#endif
				GenerateIRQ();
			}
#ifdef DEBUG2
			else
				printf("SERIO: XMTDONE Interrupt missed\n");
#endif
		}

	if ((DivNIRQ[CHAN1] -= LINE_C) < 0 ) {
		DivNIRQ[CHAN1] += DivNMax[CHAN1];
		if (IRQEN & 0x01) {
			IRQST &= 0xfe;
			GenerateIRQ();
		}
	}

	if ((DivNIRQ[CHAN2] -= LINE_C) < 0 ) {
		DivNIRQ[CHAN2] += DivNMax[CHAN2];
		if (IRQEN & 0x02) {
			IRQST &= 0xfd;
			GenerateIRQ();
		}
	}

	if ((DivNIRQ[CHAN4] -= LINE_C) < 0 ) {
		DivNIRQ[CHAN4] += DivNMax[CHAN4];
		if (IRQEN & 0x04) {
			IRQST &= 0xfb;
			GenerateIRQ();
		}
	}
}

/*****************************************************************************/
/* Module:  Update_Counter()                                                 */
/* Purpose: To process the latest control values stored in the AUDF, AUDC,   */
/*          and AUDCTL registers.  It pre-calculates as much information as  */
/*          possible for better performance.  This routine has been added    */
/*          here again as I need the precise frequency for the pokey timers  */
/*          again. The pokey emulation is therefore somewhat sub-optimal     */
/*          since the actual pokey emulation should grab the frequency values */
/*          directly from here instead of calculating them again.            */
/*                                                                           */
/* Author:  Ron Fries,Thomas Richter                                         */
/* Date:    March 27, 1998                                                   */
/*                                                                           */
/* Inputs:  chan_mask: Channel mask, one bit per channel.                    */
/*          The channels that need to be updated                             */
/*                                                                           */
/* Outputs: Adjusts local globals - no return value                          */
/*                                                                           */
/*****************************************************************************/

void Update_Counter(int chan_mask)
{

/************************************************************/
/* As defined in the manual, the exact Div_n_cnt values are */
/* different depending on the frequency and resolution:     */
/*    64 kHz or 15 kHz - AUDF + 1                           */
/*    1 MHz, 8-bit -     AUDF + 4                           */
/*    1 MHz, 16-bit -    AUDF[CHAN1]+256*AUDF[CHAN2] + 7    */
/************************************************************/

	/* only reset the channels that have changed */

	if (chan_mask & (1 << CHAN1)) {
		/* process channel 1 frequency */
		if (AUDCTL & CH1_179)
			DivNMax[CHAN1] = AUDF[CHAN1] + 4;
		else
			DivNMax[CHAN1] = (AUDF[CHAN1] + 1) * TimeBase;
		if (DivNMax[CHAN1] < LINE_C)
			DivNMax[CHAN1] = LINE_C;
	}

	if (chan_mask & (1 << CHAN2)) {
		/* process channel 2 frequency */
		if (AUDCTL & CH1_CH2) {
			if (AUDCTL & CH1_179)
				DivNMax[CHAN2] = AUDF[CHAN2] * 256 + AUDF[CHAN1] + 7;
			else
				DivNMax[CHAN2] = (AUDF[CHAN2] * 256 + AUDF[CHAN1] + 1) * TimeBase;
		}
		else
			DivNMax[CHAN2] = (AUDF[CHAN2] + 1) * TimeBase;
		if (DivNMax[CHAN2] < LINE_C)
			DivNMax[CHAN2] = LINE_C;
	}

	if (chan_mask & (1 << CHAN4)) {
		/* process channel 4 frequency */
		if (AUDCTL & CH3_CH4) {
			if (AUDCTL & CH3_179)
				DivNMax[CHAN4] = AUDF[CHAN4] * 256 + AUDF[CHAN3] + 7;
			else
				DivNMax[CHAN4] = (AUDF[CHAN4] * 256 + AUDF[CHAN3] + 1) * TimeBase;
		}
		else
			DivNMax[CHAN4] = (AUDF[CHAN4] + 1) * TimeBase;
		if (DivNMax[CHAN4] < LINE_C)
			DivNMax[CHAN4] = LINE_C;
	}
}

void POKEYStateSave( void )
{
	SaveUBYTE( &KBCODE, 1 );
	SaveUBYTE( &IRQST, 1 );
	SaveUBYTE( &IRQEN, 1 );
	SaveUBYTE( &SKSTAT, 1 );

	SaveINT( &SHIFT_KEY, 1 );
	SaveINT( &KEYPRESSED, 1 );
	SaveINT( &DELAYED_SERIN_IRQ, 1 );
	SaveINT( &DELAYED_SEROUT_IRQ, 1 );
	SaveINT( &DELAYED_XMTDONE_IRQ, 1 );

	SaveUBYTE( &AUDF[0], 4 );
	SaveUBYTE( &AUDC[0], 4 );
	SaveUBYTE( &AUDCTL, 1 );

	SaveINT((int *)&DivNIRQ[0], 4);
	SaveINT((int *)&DivNMax[0], 4);
	SaveINT((int *)&TimeBase, 1 );
}

void POKEYStateRead( void )
{
        int i;

	ReadUBYTE( &KBCODE, 1 );
	ReadUBYTE( &IRQST, 1 );
	ReadUBYTE( &IRQEN, 1 );
	ReadUBYTE( &SKSTAT, 1 );

	ReadINT( &SHIFT_KEY, 1 );
	ReadINT( &KEYPRESSED, 1 );
	ReadINT( &DELAYED_SERIN_IRQ, 1 );
	ReadINT( &DELAYED_SEROUT_IRQ, 1 );
	ReadINT( &DELAYED_XMTDONE_IRQ, 1 );

	ReadUBYTE( &AUDF[0], 4 );
	ReadUBYTE( &AUDC[0], 4 );
	ReadUBYTE( &AUDCTL, 1 );
        for (i = 0; i < 4; i++)
        {
                POKEY_PutByte(_AUDF1 + i * 2, AUDF[i]);
                POKEY_PutByte(_AUDC1 + i * 2, AUDC[i]);
        }
        POKEY_PutByte(_AUDCTL, AUDCTL);

	ReadINT((int *)&DivNIRQ[0], 4);
	ReadINT((int *)&DivNMax[0], 4);
	ReadINT((int *)&TimeBase, 1 );
}
