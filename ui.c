#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <dirent.h>
#include <stdlib.h>				/* for free() */

#include "rt-config.h"
#include "atari.h"
#include "cpu.h"
#include "gtia.h"
#include "sio.h"
#include "list.h"

#define FALSE 0
#define TRUE 1

static char charset[8192];
extern UBYTE atarixl_os[16384];
extern unsigned char ascii_to_screen[128];

extern int mach_xlxe;
extern int Ram256;

unsigned char key_to_ascii[256] =
{
	0x6C, 0x6A, 0x3B, 0x00, 0x00, 0x6B, 0x2B, 0x2A, 0x6F, 0x00, 0x70, 0x75, 0x9B, 0x69, 0x2D, 0x3D,
	0x76, 0x00, 0x63, 0x00, 0x00, 0x62, 0x78, 0x7A, 0x34, 0x00, 0x33, 0x36, 0x1B, 0x35, 0x32, 0x31,
	0x2C, 0x20, 0x2E, 0x6E, 0x00, 0x6D, 0x2F, 0x00, 0x72, 0x00, 0x65, 0x79, 0x7F, 0x74, 0x77, 0x71,
	0x39, 0x00, 0x30, 0x37, 0x7E, 0x38, 0x3C, 0x3E, 0x66, 0x68, 0x64, 0x00, 0x00, 0x67, 0x73, 0x61,

	0x4C, 0x4A, 0x3A, 0x00, 0x00, 0x4B, 0x5C, 0x5E, 0x4F, 0x00, 0x50, 0x55, 0x9B, 0x49, 0x5F, 0x7C,
	0x56, 0x00, 0x43, 0x00, 0x00, 0x42, 0x58, 0x5A, 0x24, 0x00, 0x23, 0x26, 0x1B, 0x25, 0x22, 0x21,
	0x5B, 0x20, 0x5D, 0x4E, 0x00, 0x4D, 0x3F, 0x00, 0x52, 0x00, 0x45, 0x59, 0x9F, 0x54, 0x57, 0x51,
	0x28, 0x00, 0x29, 0x27, 0x9C, 0x40, 0x7D, 0x9D, 0x46, 0x48, 0x44, 0x00, 0x00, 0x47, 0x53, 0x41,

	0x0C, 0x0A, 0x7B, 0x00, 0x00, 0x0B, 0x1E, 0x1F, 0x0F, 0x00, 0x10, 0x15, 0x9B, 0x09, 0x1C, 0x1D,
	0x16, 0x00, 0x03, 0x00, 0x00, 0x02, 0x18, 0x1A, 0x00, 0x00, 0x9B, 0x00, 0x1B, 0x00, 0xFD, 0x00,
	0x00, 0x20, 0x60, 0x0E, 0x00, 0x0D, 0x00, 0x00, 0x12, 0x00, 0x05, 0x19, 0x9E, 0x14, 0x17, 0x11,
	0x00, 0x00, 0x00, 0x00, 0xFE, 0x00, 0x7D, 0xFF, 0x06, 0x08, 0x04, 0x00, 0x00, 0x07, 0x13, 0x01,

	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

unsigned char ascii_to_screen[128] =
{
	0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
	0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
	0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
	0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x5f,
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
	0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
	0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
	0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
	0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
	0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
	0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
	0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
	0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
	0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
	0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f
};

int GetKeyPress(UBYTE * screen)
{
	int keycode;

	usleep(100000UL);
	do {
#ifndef BASIC
		Atari_DisplayScreen(screen);
#endif
		keycode = Atari_Keyboard();
	} while (keycode == AKEY_NONE);

	return key_to_ascii[keycode];
}

void Plot(UBYTE * screen, int fg, int bg, int ch, int x, int y)
{
	int offset = ascii_to_screen[(ch & 0x07f)] * 8;
	int i;
	int j;

	char *ptr;

	ptr = &screen[24 * ATARI_WIDTH + 32];

	for (i = 0; i < 8; i++) {
		UBYTE data;

		data = charset[offset++];

		for (j = 0; j < 8; j++) {
			int pixel;

			if (data & 0x80)
				pixel = colour_translation_table[fg];
			else
				pixel = colour_translation_table[bg];

			ptr[(y * 8 + i) * ATARI_WIDTH + (x * 8 + j)] = pixel;

			data = data << 1;
		}
	}
}

void Print(UBYTE * screen, int fg, int bg, char *string, int x, int y)
{
	while (*string) {
		Plot(screen, fg, bg, *string++, x, y);
		x++;
	}
}

void CenterPrint(UBYTE * screen, int fg, int bg, char *string, int y)
{
	Print(screen, fg, bg, string, (40 - strlen(string)) / 2, y);
}

void EditString(UBYTE * screen, int fg, int bg,
				int len, char *string,
				int x, int y)
{
	int offset = 0;
	int done = FALSE;

	Print(screen, fg, bg, string, x, y);

	while (!done) {
		int ascii;

		Plot(screen, bg, fg, string[offset], x + offset, y);

		ascii = GetKeyPress(screen);
		switch (ascii) {
		case 0x1e:				/* Cursor Left */
			Plot(screen, fg, bg, string[offset], x + offset, y);
			if (offset > 0)
				offset--;
			break;
		case 0x1f:				/* Cursor Right */
			Plot(screen, fg, bg, string[offset], x + offset, y);
			if ((offset + 1) < len)
				offset++;
			break;
		case 0x7e:				/* Backspace */
			Plot(screen, fg, bg, string[offset], x + offset, y);
			if (offset > 0) {
				offset--;
				string[offset] = ' ';
			}
			break;
		case 0x9b:				/* Return */
			done = TRUE;
			break;
		default:
			string[offset] = (char) ascii;
			Plot(screen, fg, bg, string[offset], x + offset, y);
			if ((offset + 1) < len)
				offset++;
			break;
		}
	}
}

void Box(UBYTE * screen, int fg, int bg, int x1, int y1, int x2, int y2)
{
	int x;
	int y;

	for (x = x1 + 1; x < x2; x++) {
		Plot(screen, fg, bg, 18, x, y1);
		Plot(screen, fg, bg, 18, x, y2);
	}

	for (y = y1 + 1; y < y2; y++) {
		Plot(screen, fg, bg, 124, x1, y);
		Plot(screen, fg, bg, 124, x2, y);
	}

	Plot(screen, fg, bg, 17, x1, y1);
	Plot(screen, fg, bg, 5, x2, y1);
	Plot(screen, fg, bg, 3, x2, y2);
	Plot(screen, fg, bg, 26, x1, y2);
}

void ClearScreen(UBYTE * screen)
{
	int x;
	int y;

	for (y = 0; y < ATARI_HEIGHT; y++)
		for (x = 0; x < ATARI_WIDTH; x++)
			screen[y * ATARI_WIDTH + x] = colour_translation_table[0];

	for (x = 0; x < 40; x++)
		for (y = 0; y < 24; y++)
			Plot(screen, 0x9a, 0x94, ' ', x, y);
}

void TitleScreen(UBYTE * screen, char *title)
{
	Box(screen, 0x9a, 0x94, 0, 0, 39, 2);
	CenterPrint(screen, 0x9a, 0x94, title, 1);
}

void SelectItem(UBYTE * screen,
				int fg, int bg,
				int index, char *items[],
				int nrows, int ncolumns,
				int xoffset, int yoffset)
{
	int x;
	int y;

	x = index / nrows;
	y = index - (x * nrows);

	x = x * (40 / ncolumns);

	x += xoffset;
	y += yoffset;

	Print(screen, fg, bg, items[index], x, y);
}

int Select(UBYTE * screen,
		   int default_item,
		   int nitems, char *items[],
		   int nrows, int ncolumns,
		   int xoffset, int yoffset,
		   int scrollable,
		   int *ascii)
{
	int index = 0;

	for (index = 0; index < nitems; index++)
		SelectItem(screen, 0x9a, 0x94, index, items, nrows, ncolumns, xoffset, yoffset);

	index = default_item;
	SelectItem(screen, 0x94, 0x9a, index, items, nrows, ncolumns, xoffset, yoffset);

	for (;;) {
		int row;
		int column;
		int new_index;

		column = index / nrows;
		row = index - (column * nrows);

		*ascii = GetKeyPress(screen);
		switch (*ascii) {
		case 0x1c:				/* Up */
			if (row > 0)
				row--;
			break;
		case 0x1d:				/* Down */
			if (row < (nrows - 1))
				row++;
			break;
		case 0x1e:				/* Left */
			if (column > 0)
				column--;
			else if (scrollable)
				return index + nitems;
			break;
		case 0x1f:				/* Right */
			if (column < (ncolumns - 1))
				column++;
			else if (scrollable)
				return index + nitems * 2;
			break;
		case 0x20:				/* Space */
		case 0x7e:				/* Backspace */
		case 0x7f:				/* Tab */
		case 0x9b:				/* Select */
			return index;
		case 0x1b:				/* Cancel */
			return -1;
		default:
			break;
		}

		new_index = (column * nrows) + row;
		if ((new_index >= 0) && (new_index < nitems)) {
			SelectItem(screen, 0x9a, 0x94, index, items, nrows, ncolumns, xoffset, yoffset);

			index = new_index;
			SelectItem(screen, 0x94, 0x9a, index, items, nrows, ncolumns, xoffset, yoffset);
		}
	}
}

void SelectSystem(UBYTE * screen)
{
	int system;
	int ascii;

	char *menu[7] =
	{
		"Atari OS/A",
		"Atari OS/B",
		"Atari 800XL",
		"Atari 130XE",
		"Atari 320XE (RAMBO)",
		"Atari 320XE (COMPY SHOP)",
		"Atari 5200"
	};

	ClearScreen(screen);
	TitleScreen(screen, "Select System");
	Box(screen, 0x9a, 0x94, 0, 3, 39, 23);

	system = Select(screen, 0, 7, menu, 7, 1, 1, 4, FALSE, &ascii);

	switch (system) {
	case 0:
		Ram256 = 0;
		Initialise_AtariOSA();
		break;
	case 1:
		Ram256 = 0;
		Initialise_AtariOSB();
		break;
	case 2:
		Ram256 = 0;
		Initialise_AtariXL();
		break;
	case 3:
		Ram256 = 0;
		Initialise_AtariXE();
		break;
	case 4:
		Ram256 = 1;
		Initialise_Atari320XE();
		break;
	case 5:
		Ram256 = 2;
		Initialise_Atari320XE();
		break;
	case 6:
		Ram256 = 0;
		Initialise_Atari5200();
		break;
	default:
		break;
	}
}

int FilenameSort(char *filename1, char *filename2)
{
	return strcmp(filename1, filename2);
}

List *GetDirectory(char *directory)
{
	DIR *dp = NULL;
	List *list = NULL;

	dp = opendir(directory);
	if (dp) {
		struct dirent *entry;

		list = ListCreate();
		if (!list) {
			printf("ListCreate(): Failed\n");
			return NULL;
		}
		while ((entry = readdir(dp))) {
			char *filename;

			filename = strdup(entry->d_name);
			if (!filename) {
				perror("strdup");
				return NULL;
			}
			ListAddTail(list, filename);
		}

		closedir(dp);

		ListSort(list, FilenameSort);
	}
	return list;
}

int FileSelector(UBYTE * screen, char *directory, char *full_filename)
{
	List *list;
	int flag = FALSE;

	list = GetDirectory(directory);
	if (list) {
		char *filename;
		int nitems = 0;
		int item = 0;
		int done = FALSE;
		int offset = 0;
		int nfiles = 0;

#define NROWS 19
#define NCOLUMNS 2
#define MAX_FILES (NROWS * NCOLUMNS)

		char *files[MAX_FILES];

		ListReset(list);
		while (ListTraverse(list, (void *) &filename))
			nfiles++;

		while (!done) {
			int ascii;

			ListReset(list);
			for (nitems = 0; nitems < offset; nitems++)
				ListTraverse(list, (void *) &filename);

			for (nitems = 0; nitems < MAX_FILES; nitems++) {
				if (ListTraverse(list, (void *) &filename)) {
					files[nitems] = filename;
				}
				else
					break;
			}

			ClearScreen(screen);
			TitleScreen(screen, "Select File");
			Box(screen, 0x9a, 0x94, 0, 3, 39, 23);

			item = Select(screen, item, nitems, files, NROWS, NCOLUMNS, 1, 4, TRUE, &ascii);
			if (item >= (nitems * 2 + NROWS)) {		/* Scroll Right */
				if ((offset + NROWS + NROWS) < nfiles)
					offset += NROWS;
				item = item % nitems;
			}
			else if (item >= nitems) {	/* Scroll Left */
				if ((offset - NROWS) >= 0)
					offset -= NROWS;
				item = item % nitems;
			}
			else if (item != -1) {
#ifndef BACK_SLASH
				sprintf(full_filename, "%s/%s", directory, files[item]);
#else							/* DOS, TOS fs */
				sprintf(full_filename, "%s\\%s", directory, files[item]);
#endif
				flag = TRUE;
				break;
			}
			else
				break;
		}

		ListFree(list, free);
	}
	return flag;
}

void DiskManagement(UBYTE * screen)
{
	char *menu[8] =
	{
		NULL,					/* D1 */
		NULL,					/* D2 */
		NULL,					/* D3 */
		NULL,					/* D4 */
		NULL,					/* D5 */
		NULL,					/* D6 */
		NULL,					/* D7 */
		NULL,					/* D8 */
	};

	int done = FALSE;
	int dsknum = 0;

	menu[0] = sio_filename[0];
	menu[1] = sio_filename[1];
	menu[2] = sio_filename[2];
	menu[3] = sio_filename[3];
	menu[4] = sio_filename[4];
	menu[5] = sio_filename[5];
	menu[6] = sio_filename[6];
	menu[7] = sio_filename[7];

	while (!done) {
		char filename[256];
		int ascii;

		ClearScreen(screen);
		TitleScreen(screen, "Disk Management");
		Box(screen, 0x9a, 0x94, 0, 3, 39, 23);

		Print(screen, 0x9a, 0x94, "D1:", 1, 4);
		Print(screen, 0x9a, 0x94, "D2:", 1, 5);
		Print(screen, 0x9a, 0x94, "D3:", 1, 6);
		Print(screen, 0x9a, 0x94, "D4:", 1, 7);
		Print(screen, 0x9a, 0x94, "D5:", 1, 8);
		Print(screen, 0x9a, 0x94, "D6:", 1, 9);
		Print(screen, 0x9a, 0x94, "D7:", 1, 10);
		Print(screen, 0x9a, 0x94, "D8:", 1, 11);

		dsknum = Select(screen, dsknum, 8, menu, 8, 1, 4, 4, FALSE, &ascii);
		if (dsknum != -1) {
			if (ascii == 0x9b) {
				if (FileSelector(screen, atari_disk_dir, filename)) {
					SIO_Dismount(dsknum + 1);
					SIO_Mount(dsknum + 1, filename);
				}
			}
			else {
				if (strcmp(sio_filename[dsknum], "Empty") == 0)
					SIO_DisableDrive(dsknum + 1);
				else
					SIO_Dismount(dsknum + 1);
			}
		}
		else
			done = TRUE;
	}
}

void CartManagement(UBYTE * screen)
{
	typedef struct {
		UBYTE id[4];
		UBYTE type[4];
		UBYTE checksum[4];
		UBYTE gash[4];
	} Header;

	const int CART_UNKNOWN = 0;
	const int CART_STD_8K = 1;
	const int CART_STD_16K = 2;
	const int CART_OSS = 3;
	const int CART_AGS = 4;

	const int nitems = 5;

	static char *menu[5] =
	{
		"Create Cartridge from ROM image",
		"Extract ROM image from Cartridge",
		"Insert Cartridge",
		"Remove Cartridge",
		"Enable PILL Mode"
	};

	int done = FALSE;
	int option = 2;

	while (!done) {
		char filename[256];
		int ascii;

		ClearScreen(screen);
		TitleScreen(screen, "Cartridge Management");
		Box(screen, 0x9a, 0x94, 0, 3, 39, 23);

		option = Select(screen, option, nitems, menu, nitems, 1, 1, 4, FALSE, &ascii);
		switch (option) {
		case 0:
			if (FileSelector(screen, atari_rom_dir, filename)) {
				UBYTE image[32769];
				int type = CART_UNKNOWN;
				int nbytes;
				int fd;

				fd = open(filename, O_RDONLY, 0777);
				if (fd == -1) {
					perror(filename);
					exit(1);
				}
				nbytes = read(fd, image, sizeof(image));
				switch (nbytes) {
				case 8192:
					type = CART_STD_8K;
					break;
				case 16384:
					{
						const int nitems = 2;
						static char *menu[2] =
						{
							"Standard 16K Cartridge",
							"OSS Super Cartridge"
						};

						int option = 0;

						Box(screen, 0x9a, 0x94, 8, 10, 31, 13);

						option = Select(screen, option,
										nitems, menu,
										nitems, 1,
										9, 11, FALSE, &ascii);
						switch (option) {
						case 0:
							type = CART_STD_16K;
							break;
						case 1:
							type = CART_OSS;
							break;
						default:
							continue;
						}
					}
					break;
				case 32768:
					type = CART_AGS;
				}

				close(fd);

				if (type != CART_UNKNOWN) {
					Header header;

					int checksum = 0;
					int i;

					char fname[33];

					memcpy(fname, "                                ", 32);
					Box(screen, 0x9a, 0x94, 3, 9, 36, 11);
					Print(screen, 0x94, 0x9a, "Filename", 4, 9);
					EditString(screen, 0x9a, 0x94, 32, fname, 4, 10);
					fname[32] = '\0';
					RemoveSpaces(fname);

					for (i = 0; i < nbytes; i++)
						checksum += image[i];

					header.id[0] = 'C';
					header.id[1] = 'A';
					header.id[2] = 'R';
					header.id[3] = 'T';
					header.type[0] = (type >> 24) & 0xff;
					header.type[1] = (type >> 16) & 0xff;
					header.type[2] = (type >> 8) & 0xff;
					header.type[3] = type & 0xff;
					header.checksum[0] = (checksum >> 24) & 0xff;
					header.checksum[1] = (checksum >> 16) & 0xff;
					header.checksum[2] = (checksum >> 8) & 0xff;
					header.checksum[3] = checksum & 0xff;
					header.gash[0] = '\0';
					header.gash[1] = '\0';
					header.gash[2] = '\0';
					header.gash[3] = '\0';

					sprintf(filename, "%s/%s", atari_rom_dir, fname);
					fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0777);
					if (fd != -1) {
						write(fd, &header, sizeof(header));
						write(fd, image, nbytes);
						close(fd);
					}
				}
			}
			break;
		case 1:
			if (FileSelector(screen, atari_rom_dir, filename)) {
				int fd;

				fd = open(filename, O_RDONLY, 0777);
				if (fd != -1) {
					Header header;
					UBYTE image[32769];
					char fname[33];
					int nbytes;

					read(fd, &header, sizeof(header));
					nbytes = read(fd, image, sizeof(image));

					close(fd);

					memcpy(fname, "                                ", 32);
					Box(screen, 0x9a, 0x94, 3, 9, 36, 11);
					Print(screen, 0x94, 0x9a, "Filename", 4, 9);
					EditString(screen, 0x9a, 0x94, 32, fname, 4, 10);
					fname[32] = '\0';
					RemoveSpaces(fname);

					sprintf(filename, "%s/%s", atari_rom_dir, fname);

					fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0777);
					if (fd != -1) {
						write(fd, image, nbytes);
						close(fd);
					}
				}
			}
			break;
		case 2:
			if (FileSelector(screen, atari_rom_dir, filename)) {
				if (!Insert_Cartridge(filename)) {
					const int nitems = 4;
					static char *menu[4] =
					{
						"Standard 8K Cartridge",
						"Standard 16K Cartridge",
						"OSS Super Cartridge",
						"Atari 5200 Cartridge"
					};

					int option = 0;

					Box(screen, 0x9a, 0x94, 8, 10, 31, 15);

					option = Select(screen, option,
									nitems, menu,
									nitems, 1,
									9, 11, FALSE, &ascii);
					switch (option) {
					case 0:
						Insert_8K_ROM(filename);
						break;
					case 1:
						Insert_16K_ROM(filename);
						break;
					case 2:
						Insert_OSS_ROM(filename);
						break;
					case 3:
						Insert_32K_5200ROM(filename);
						break;
					}
				}
				Coldstart();
			}
			break;
		case 3:
			Remove_ROM();
			Coldstart();
			break;
		case 4:
			EnablePILL();
			Coldstart();
			break;
		default:
			done = TRUE;
			break;
		}
	}
}

void AboutEmulator(UBYTE * screen)
{
	ClearScreen(screen);

	Box(screen, 0x9a, 0x94, 0, 0, 39, 8);
	CenterPrint(screen, 0x9a, 0x94, ATARI_TITLE, 1);
	CenterPrint(screen, 0x9a, 0x94, "Copyright (c) 1995-1998 David Firth", 2);
	CenterPrint(screen, 0x9a, 0x94, "E-Mail: david@signus.demon.co.uk", 3);
	CenterPrint(screen, 0x9a, 0x94, "http://www.signus.demon.co.uk/", 4);
	CenterPrint(screen, 0x9a, 0x94, "Atari PokeySound 2.4", 6);
	CenterPrint(screen, 0x9a, 0x94, "Copyright (c) 1996-1998 Ron Fries", 7);

	Box(screen, 0x9a, 0x94, 0, 9, 39, 23);
	CenterPrint(screen, 0x9a, 0x94, "This program is free software; you can", 10);
	CenterPrint(screen, 0x9a, 0x94, "redistribute it and/or modify it under", 11);
	CenterPrint(screen, 0x9a, 0x94, "the terms of the GNU General Public", 12);
	CenterPrint(screen, 0x9a, 0x94, "License as published by the Free", 13);
	CenterPrint(screen, 0x9a, 0x94, "Software Foundation; either version 1,", 14);
	CenterPrint(screen, 0x9a, 0x94, "or (at your option) any later version.", 15);

	CenterPrint(screen, 0x94, 0x9a, "Press any Key to Continue", 22);
	GetKeyPress(screen);
}

void ui(UBYTE * screen)
{
	static int initialised = FALSE;
	int option = 0;
	char filename[256];
	int done = FALSE;

	const int nitems = 7;
	char *menu[7] =
	{
		"About the Emulator",
		"Select System",
		"Disk Management",
		"Cartridge Management",
		"Power On Reset (Warm Start)",
		"Power Off Reset (Cold Start)",
		"Exit Emulator"
	};

	if (!initialised) {
		if (mach_xlxe)
			memcpy(charset, atarixl_os + 0x2000, 8192);
		else
			memcpy(charset, memory + 0xe000, 8192);
		initialised = TRUE;
	}
	while (!done) {
		int ascii;

		ClearScreen(screen);
		TitleScreen(screen, ATARI_TITLE);
		Box(screen, 0x9a, 0x94, 0, 3, 39, 23);

		option = Select(screen, option, nitems, menu,
						nitems, 1, 1, 4, FALSE, &ascii);

		switch (option) {
		case -1:
			done = TRUE;
			break;
		case 0:
			AboutEmulator(screen);
			break;
		case 1:
			SelectSystem(screen);
			break;
		case 2:
			DiskManagement(screen);
			break;
		case 3:
			CartManagement(screen);
			break;
		case 4:
			Warmstart();
			break;
		case 5:
			Coldstart();
			break;
		case 6:
			Atari800_Exit(0);
			exit(0);
		}
	}
}