/*
 * Usage: mkimg -input <filename
 *              -image filename
 *              -header filename
 *              hexaddr1
 *              hexaddr2
 *
 * Loads the input file into a 64K area of memory. The
 * input file is in standard Atari Binary load format.
 * The memory is initially filled with zeros. After the
 * memory has been loaded the program creates either an
 * image file or a standard C header file that contains
 * the memory starting with hexaddr1 at going up to,
 * but not including, hexaddr2.
 */

#include <stdio.h>
#include <ctype.h>
#include <fcntl.h>
#include "config.h"

#define FALSE 0
#define TRUE 1

typedef enum {
	Expect_Header1,
	Expect_Header2,
	Expect_StartLo,
	Expect_StartHi,
	Expect_FinishLo,
	Expect_FinishHi,
	Expect_Data
} State;

main(int argc, char *argv[], char *envp[])
{
	unsigned char image[65536];
	char *in_filename = NULL;
	char *image_filename = NULL;
	char *header_filename = NULL;
	int error = FALSE;
	int start_addr = 0;
	int finish_addr = 0;
	int addr1 = -1;
	int addr2 = -1;
	int addr;
	FILE *f;
	int i;

	State state = Expect_Header1;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-input") == 0)
			in_filename = argv[++i];
		else if (strcmp(argv[i], "-image") == 0)
			image_filename = argv[++i];
		else if (strcmp(argv[i], "-header") == 0)
			header_filename = argv[++i];
		else if (addr1 == -1)
			sscanf(argv[i], "%x", &addr1);
		else if (addr2 == -1)
			sscanf(argv[i], "%x", &addr2);
		else
			error = TRUE;
	}

	if (!in_filename || (!image_filename && !header_filename) ||
		error || (addr1 == -1) || (addr2 == -1)) {
		printf("Usage: %s -input in_fname {-image image_fname|-header header_fname} hexaddr1 hexaddr2\n",
			   argv[0]);
		exit(0);
	}
	memset(image, 0, 65536);

	f = fopen(in_filename, "rb");
	if (!f) {
		perror(in_filename);
		exit(1);
	}
	while (1) {
		unsigned char byte;

		if (fread(&byte, 1, 1, f) != 1)
			break;

		switch (state) {
		case Expect_Header1:
			if (byte == 0xff)
				state = Expect_Header2;
			else
				printf("Error: Expecting Header1\n");
			break;
		case Expect_Header2:
			if (byte == 0xff)
				state = Expect_StartLo;
			else
				printf("Error: Expecting Header2\n");
			break;
		case Expect_StartLo:
			start_addr = (start_addr & 0xff00) | byte;
			state = Expect_StartHi;
			break;
		case Expect_StartHi:
			start_addr = (start_addr & 0x00ff) | (byte << 8);
			state = Expect_FinishLo;
			printf("StartAddr = %x\n", start_addr);
			if (start_addr == 0xffff) {
				printf("Oops thats a header\n");
				state = Expect_StartLo;
			}
			break;
		case Expect_FinishLo:
			finish_addr = (finish_addr & 0xff00) | byte;
			state = Expect_FinishHi;
			break;
		case Expect_FinishHi:
			finish_addr = (finish_addr & 0x00ff) | (byte << 8);
			state = Expect_Data;
			addr = start_addr;
			printf("FinishAddr = %x\n", finish_addr);
			break;
		case Expect_Data:
			image[addr++] = byte;
			if (addr > finish_addr)
				state = Expect_StartLo;
			break;
		default:
			printf("Error: Invalid State\n");
			exit(1);
		}
	}

	fclose(f);

	/*
	 * Write image to file
	 */

	if (image_filename) {
		f = fopen(image_filename, "wb");
		if (!f) {
			perror(image_filename);
			exit(1);
		}
		fwrite(&image[addr1], 1, addr2 - addr1 + 1, f);

		fclose(f);
	}
	if (header_filename) {
		FILE *fp;
		char *ptr;
		int j;

		fp = fopen(header_filename, "wb");
		if (!fp) {
			perror(header_filename);
			exit(1);
		}
		for (ptr = header_filename; *ptr; ptr++) {
			if (!isalnum(*ptr))
				*ptr = '_';
		}

		fprintf(fp, "#ifndef __%s__\n", header_filename);
		fprintf(fp, "#define __%s__\n\n", header_filename);

		fprintf(fp, "static char %s[] =\n{\n\t", header_filename);

		for (i = addr1, j = 0; i < addr2; i++) {
			fprintf(fp, "0x%02x,", image[i]);

			if (++j == 8) {
				fprintf(fp, "\n\t");
				j = 0;
			}
		}

		fprintf(fp, "0x%02x\n", image[addr2]);
		fprintf(fp, "};\n");

		fprintf(fp, "\n#endif\n");

		fclose(fp);
	}
}
