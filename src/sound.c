/* $Id: sound.c,v 1.4 2001/04/08 05:59:32 knik Exp $ */
#include <stdio.h>
#include <unistd.h>

#include "config.h"

#ifdef SOUND
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/soundcard.h>

#include "pokeysnd.h"

#include "sndsave.h"

#define FRAGSIZE	7

#define FALSE 0
#define TRUE 1

#define DEFDSPRATE 22050

static char *dspname = "/dev/dsp";
static int dsprate = DEFDSPRATE;
static int fragstofill = 0;
static int snddelay = 40;		/* delay in milliseconds */

static int sound_enabled = TRUE;
static int dsp_fd;

void Sound_Initialise(int *argc, char *argv[])
{
	int i, j;
	struct audio_buf_info abi;

	for (i = j = 1; i < *argc; i++) {
		if (strcmp(argv[i], "-sound") == 0)
			sound_enabled = TRUE;
		else if (strcmp(argv[i], "-nosound") == 0)
			sound_enabled = FALSE;
		else if (strcmp(argv[i], "-dsprate") == 0)
			sscanf(argv[++i], "%d", &dsprate);
		else if (strcmp(argv[i], "-snddelay") == 0)
			sscanf(argv[++i], "%d", &snddelay);
		else {
			if (strcmp(argv[i], "-help") == 0) {
				printf("\t-sound                    enable sound\n"
				       "\t-nosound                  disable sound\n"
				       "\t-dsprate <rate>           set dsp rate\n"
				       "\t-snddelay <milliseconds>  set sound delay\n"
				      );
			}
			argv[j++] = argv[i];
		}
	}

	*argc = j;

	if (sound_enabled) {
		if ((dsp_fd = open(dspname, O_WRONLY)) == -1) {
			perror(dspname);
			sound_enabled = 0;
			return;
		}

		if (ioctl(dsp_fd, SNDCTL_DSP_SPEED, &dsprate)) {
			fprintf(stderr, "%s: cannot set %d speed\n", dspname, dsprate);
			close(dsp_fd);
			sound_enabled = 0;
			return;
		}

		i = AFMT_U8;
		if (ioctl(dsp_fd, SNDCTL_DSP_SETFMT, &i)) {
			fprintf(stderr, "%s: cannot set 8-bit sample\n", dspname);
			close(dsp_fd);
			sound_enabled = 0;
			return;
		}
#ifdef STEREO
		i = 1;
		if (ioctl(dsp_fd, SNDCTL_DSP_STEREO, &i)) {
			fprintf(stderr, "%s: cannot set stereo\n", dspname);
			close(dsp_fd);
			sound_enabled = 0;
			return;
		}
#endif

		fragstofill = ((dsprate * snddelay / 1000) >> FRAGSIZE) + 1;
		if (fragstofill > 100)
			fragstofill = 100;

		/* fragments of size 2^FRAGSIZE bytes */
		i = ((fragstofill + 1) << 16) | FRAGSIZE;
		if (ioctl(dsp_fd, SNDCTL_DSP_SETFRAGMENT, &i)) {
			fprintf(stderr, "%s: cannot set fragments\n", dspname);
			close(dsp_fd);
			sound_enabled = 0;
			return;
		}

		if (ioctl(dsp_fd, SNDCTL_DSP_GETOSPACE, &abi)) {
			fprintf(stderr, "%s: unable to get output space\n", dspname);
			close(dsp_fd);
			sound_enabled = 0;
			return;
		}

#ifdef STEREO
		Pokey_sound_init(FREQ_17_EXACT, dsprate, 2);
#else
		Pokey_sound_init(FREQ_17_EXACT, dsprate, 1);
#endif
	}
}

void Sound_Pause(void)
{
	if (sound_enabled) {
		/* stop audio output */
	}
}

void Sound_Continue(void)
{
	if (sound_enabled) {
		/* start audio output */
	}
}

void Sound_Exit(void)
{
	if (sound_enabled)
		close(dsp_fd);
}

void Sound_Update(void)
{
	int i;
	struct audio_buf_info abi;
	char dsp_buffer[1 << FRAGSIZE];

	if (!sound_enabled)
		return;

	if (ioctl(dsp_fd, SNDCTL_DSP_GETOSPACE, &abi))
		return;
		
	i = abi.fragstotal - abi.fragments;

	/* we need fragstofill fragments to be filled */
#ifdef STEREO
	for (; i < fragstofill*2; i++) {
#else
	for (; i < fragstofill; i++) {
#endif
		Pokey_process(dsp_buffer, sizeof(dsp_buffer));
		write(dsp_fd, dsp_buffer, sizeof(dsp_buffer));
	}
}
#endif	/* SOUND */

/*
 $Log: sound.c,v $
 Revision 1.4  2001/04/08 05:59:32  knik
 sound_pause/continue removed if no sound used

 Revision 1.3  2001/03/24 06:28:07  knik
 help fixed and control message removed

 */
