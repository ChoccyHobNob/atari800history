;This code is copyrighted by Empty Head (c)1997, but
;you can use it without any charge in your own programs
;use it on your own risk ;)


;DEBUG ;if it is active it is possible to trace through 6502 memory
;SERVER ;if conrol server is active
;C_BUGGING ;debug in C - logical, isn't it ? :)

	ifd DEBUG
	bra START
	endc
	OPT		P=68040,O+,W-

	ifnd DEBUG
	xref _GETBYTE ;procedures for A800 bytes
	xref _PUTBYTE
	xref _Escape
	xref _break_addr
	xref _tisk
	xdef _regPC
	xdef _regA
	xdef _regP ;/* Processor Status Byte (Partial) */
	xdef _regS
	xdef _regX
	xdef _regY
	xref _memory
	xref _attrib
	xdef _IRQ
	xdef _NMI
	xdef _RTI
	xdef _GO
	xdef _CPUGET
	xdef _CPU_INIT
	xdef _OPMODE_TABLE
	ifd C_BUGGING
	xref _CEKEJ
	xdef _ADRESA
	xdef _AIRQ
	endc
	endc

regA
_regA	ds.b 1   ;d0 -A
regX
_regX	ds.b 1   ;d1 -X
regY
_regY	ds.b 1   ;d2 -Y
regS
_regS	ds.b 1   ;stack
regPC
_regPC	ds.w 1   ;a4 PC
regP
VBDIFLAG	         ;same as regP
_regP	ds.b 1   ;   -CCR
IRQ	         ;I have to reserve it there because other it is 32-bit number (in GCC)
_IRQ	ds.b 1


	even


CD	equr a6 ;cycles counter down
_pointer equr a1
memory_pointer equr a5
attrib_pointer equr a3
stack_pointer equr a2
PC6502	equr a4


ZFLAG	equr d5 ;we used it straight in shifting, because it is faster than move again
                    ;I mean rol, ror, asl, asr, lsr, lsl
NFLAG	equr d3 ;
CCR6502	equr d4 ;only carry is usable (Extended on 68000)
A	equr d0
X	equr d1
Y	equr d2  ;$206 ;d2

;d6	contains usually adress where we are working
;d7	contains is a working register


LoHi  macro		;change order of lo and hi byte in d6
      ror.w #8,d7
      endm

;	==========================================================
;	Emulated Registers and Flags are kept local to this module
;	==========================================================



;#define UPDATE_GLOBAL_REGS regPC=PC;regS=S;regA=A;regX=X;regY=Y
UPDATE_GLOBAL_REGS	macro
	sub.l memory_pointer,PC6502
	sub.l memory_pointer,stack_pointer
	lea -$101(stack_pointer),stack_pointer
	move.w stack_pointer,d6
	lea _regP(pc),a1
	move.w PC6502,-(a1) ;_PC6502
	move.b d6,-(a1) ;regS
	move.b Y,-(a1) ;regY
	move.b X,-(a1) ;regX
	move.b A,-(a1) ;regA
	endm

;#define UPDATE_LOCAL_REGS PC=regPC;S=regS;A=regA;X=regX;Y=regY
UPDATE_LOCAL_REGS macro
	lea _regA(pc),a1
	clr.w A
	move.b (a1)+,A ;A register
	clr.w X
	move.b (a1)+,X ;X
	clr.w Y
	move.b (a1)+,Y ;Y
	clr.l d7
	move.b (a1)+,d7 ;stack regS
	lea $101(memory_pointer),stack_pointer
	add.l d7,stack_pointer
	move.w (a1)+,d7
	move.l memory_pointer,PC6502
	add.l d7,PC6502
	endm





;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~ WAKE UP PROCESSOR IN DEBUG MODE ~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


	ifd DEBUG
START:      bsr _CPU_INIT ;make from OPCODE TABLE & MODE TABLE -  OPMODE TABLE
	clr.l -(a7)
	move.w #32,-(a7)
	trap #1
	addq.l #6,a7
	move.l d0,-(a7)
	lea _memory,memory_pointer
	clr.b IRQ ;no interrupt
	move.b #$20,regP ;unused bit is always 1
	move.b #$ff,regS ;set up stack to the star
	move.w (memory_pointer,$fffc.l),d7 ;start addres
	;move.w #$0020,d7
	LoHi
	move.w d7,regPC
	UPDATE_LOCAL_REGS
	clr.l d0
	;move.l #3560,d0
	;lea TEST,a0
	move.l $4ba,-(a7)
ANOTHER:
	move.l #27360,-(a7)  ;one screen
	bsr _GO
	addq.l #4,a7
	;move.l (a7)+,a0
	;move.l d7,(a0)+
	sub.l #1,AAA
	bne.s ANOTHER
	move.l $4ba.l,d7
	sub.l (a7)+,d7
	move.l d7,$200.w
	move.w #32,-(a7)
	trap #1
	addq.l #6,a7
	illegal
	clr.w -(a7)
	trap #1
	endc

	section data
AAA:	dc.l 50
	section text



_CPU_INIT:
	movem.l a2/a3/d2,-(a7)  ;copy opcyc table
	lea OPMODE_TABLE,a1
	;move.l a1,d2 ;we need to start on a word adress
	;add.l #4,d2
	;and.l #$fffffc,d2
	;move.l d2,a1
	;lea OPCODE_TABLE,a1 ;3rd case of jump (mode, get, then this command)
	lea MODE_TABLE2,a0 ;1st case of jump (mode)
	lea MODE_TABLE1,a3 ;2nd case of jump (jump after mode (in put case it is instruction, if get then we will call get byte routine)
	move.w #255,d0
COPY

	move.l (a0)+,(a1)+ ;base jump (instruction or mode)
	move.l (a3)+,d2    ;jump
	cmp.l #opcode_81,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_84,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_85,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_86,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_8c,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_8d,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_8e,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_91,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_94,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_95,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_96,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_99,d2
	beq.s WRITE_WRITE
	cmp.l #opcode_9d,d2
	beq.s WRITE_WRITE
	;sub.l #JUMP_CODE+2,d2
	move.l d2,(a1)+ ;write jump down
	;addq.l #2,a1
	bra.s NEXT
WRITE_WRITE:
	;sub.l #JUMP_CODE+2,d2
	bset #31,d2
	move.l d2,(a1)+ ;write jump down
	;addq.l #2,a1

NEXT:	dbf d0,COPY
	movem.l (a7)+,a2/a3/d2
	rts


;these are bit in MC68000 CCR register
NB68	equ 3
EB68	equ 4 ;used as a carry in 6502 emulation
ZB68	equ 2
OB68	equ 1
CB68	equ 0

N_FLAG equ $80    ;tested in ZN flag in the same way as usual on 6502
N_FLAGB equ 7
V_FLAG equ $40
V_FLAGB equ 6
G_FLAG equ $20
G_FLAGB equ $5
B_FLAG equ $10
B_FLAGB equ 4
D_FLAG equ $08
D_FLAGB equ 3
I_FLAG equ $04
I_FLAGB equ 2
Z_FLAG equ $02
Z_FLAGB equ 1
C_FLAG equ $01
C_FLAGB equ 0

;void CPU_GetStatus (void) - assembler (CPU_ST.S)
;void CPU_PutStatus (void) - assembler (CPU_ST.S)
;void CPU_Reset (void) - C (CPU_ST.C)
;void SetRAM (int addr1, int addr2) - C (CPU_ST.C)
;void SetROM (int addr1, int addr2) - C (CPU_ST.C)
;void SetHARDWARE (int addr1, int addr2) - C (CPU_ST.C)
;void NMI (void) - C (CPU_ST.C)
;void GO (int cycles); - assembler (CPU_ST.S)



SetI	macro
	bset #I_FLAGB,_regP
	endm

ClrI	macro
	bclr #I_FLAGB,_regP
	endm

SetB	macro
	bset #B_FLAGB,_regP
	endm

ClrD	macro
	bclr #D_FLAGB,_regP
	endm

SetD	macro
	bset #D_FLAGB,_regP
	endm

;#define SetN regP|=N_FLAG
;#define ClrN regP&=(~N_FLAG)
;#define SetV regP|=V_FLAG
;#define ClrV regP&=(~V_FLAG)
;#define SetB regP|=B_FLAG
;#define ClrB regP&=(~B_FLAG)
;#define SetD regP|=D_FLAG
;#define ClrD regP&=(~D_FLAG)
;#define SetI regP|=I_FLAG
;#define ClrI regP&=(~I_FLAG)
;#define SetZ regP|=Z_FLAG
;#define ClrZ regP&=(~Z_FLAG)
;#define SetC regP|=C_FLAG
;#define ClrC regP&=(~C_FLAG)

;extern UBYTE memory[65536];

;extern int IRQ;

;#endif


goto 	macro
	bra \1
	endm


;static char *rcsid = "$Id: cpu_m68k.s,v 1.2 1998/02/21 15:02:46 david Exp $";



;static UBYTE	N;	/* bit7 zero (0) or bit 7 non-zero (1) */
;static UBYTE	Z;	/* zero (0) or non-zero (1) */
;static UBYTE	V;
;static UBYTE	C;	/* zero (0) or one(1) */

RAM 	equ 0
ROM 	equ 1
HARDWARE    equ 2


;/*
; * The following array is used for 6502 instruction profiling
; */

;int count[256];
;UBYTE memory[65536];

;int IRQ;

;static UBYTE attrib[65536];


;#define	GetByte(addr)	((attrib[addr] == HARDWARE) ? Atari800_GetByte(addr) : memory[addr])
;#define	PutByte(addr,byte)	if (attrib[addr] == RAM) memory[addr] = byte; else if (attrib[addr] == HARDWARE) if (Atari800_PutByte(addr,byte)) break;

;/*
;	===============================================================
;	Z flag: This actually contains the result of an operation which
;		would modify the Z flag. The value is tested for
;		equality by the BEQ and BNE instruction.
;	===============================================================
;*/

; Bit    : 76543210
; CCR6502: ***XNZVC
; _RegP  : NV*BDIZC

ConvertSTATUS_RegP macro
	move.b _regP,d6 ;put flag VBDI into d6
	bset #C_FLAGB,d6 ;put there carry flag
	btst #EB68,CCR6502
	bne.s .SETC\@
	bclr #C_FLAGB,d6
.SETC\@	bset #N_FLAGB,d6 ;put there Negative flag
	tst.b NFLAG
	bmi.s .SETN\@
	bclr #N_FLAGB,d6
.SETN\@	bset #Z_FLAGB,d6 ;put there zero flag
	tst.b ZFLAG
	beq.s .SETZ\@   ;is there beware! reverse compare is ok
	bclr #Z_FLAGB,d6
.SETZ\@
	endm

ConvertRegP_STATUS macro
	move.b _regP,d6
	moveq #-1,CCR6502
	btst #C_FLAGB,d6
	bne.s .SETC\@
	clr.w CCR6502
.SETC\@	clr.b ZFLAG
	btst #Z_FLAGB,d6
	bne.s .SETZ\@ ;reverse is ok
	not.b ZFLAG
.SETZ\@	clr.b NFLAG
	btst #N_FLAGB,d6
	beq.s .SETN\@
	not.b NFLAG
.SETN\@
	endm


CPU_GetStatus macro
	ConvertSTATUS_RegP
	move.b d6,_regP
	endm

CPU_PutStatus macro
	ConvertRegP_STATUS
	endm


PHP	macro
	ConvertSTATUS_RegP
	move.b d6,-(stack_pointer)
	endm

PLP	macro
	move.b (stack_pointer)+,_regP
	ConvertRegP_STATUS
	endm


;#define AND(t_data) data = t_data; Z = N = A &= data;
;#define CMP(t_data) data = t_data; Z = N = A - data; C = (A >= data)
;#define CPX(t_data) data = t_data; Z = N = X - data; C = (X >= data);
;#define CPY(t_data) data = t_data; Z = N = Y - data; C = (Y >= data);
;#define EOR(t_data) data = t_data; Z = N = A ^= data;
;#define LDA(data) Z = N = A = data;
;#define LDX(data) Z = N = X = data;
;#define LDY(data) Z = N = Y = data;
;#define ORA(t_data) data = t_data; Z = N = A |= data

;#define PHP data =  (N & 0x80); \
;            data |= V ? 0x40 : 0; \
;            data |= (regP & 0x3c); \
;	    data |= (Z == 0) ? 0x02 : 0; \
;	    data |= C; \
;	    memory[0x0100 + S--] = data;
;
;#define PLP data = memory[0x0100 + ++S]; \
;	    N = (data & 0x80); \
;	    V = (data & 0x40) ? 1 : 0; \
;	    Z = (data & 0x02) ? 0 : 1; \
;	    C = (data & 0x01); \
;            regP = (data & 0x3c) | 0x20;
;


CPUGET:
_CPUGET:
	ConvertSTATUS_RegP
	move.b d6,_regP
	rts



NMI:
_NMI:
	movem.l d0-d7/a0-a6,-(a7)
	lea _memory,memory_pointer
	move.w _regPC,d6 ;we will put adress on stack of 6502
	ror.w #8,d6
            clr.l d7	    ;find stack in memory
	move.b _regS,d7
            move.l d7,stack_pointer
	add.l memory_pointer,stack_pointer
	lea $101(stack_pointer),stack_pointer
	move.w d6,-(stack_pointer) ;put back adress onto stack
	move.b _regP,-(stack_pointer) ;put P onto stack YEAAAH!
	SetI

	;put regPC & Stack pointer adress on its place
	move.w (memory_pointer,$fffa.l),d7
	LoHi
	move.w d7,_regPC
	lea -$101(stack_pointer),stack_pointer
	move.l stack_pointer,d7 ;put stack
	sub.l memory_pointer,d7
	move.b d7,_regS
	movem.l (a7)+,d0-d7/a0-a6
	ifd SERVER
	move.w #1,WAIT
	endc
	rts

  	;UBYTE S = regS;
  	;UBYTE data;

  	;memory[0x0100 + S--] = regPC >> 8;
  	;memory[0x0100 + S--] = regPC & 0xff;
  	;PHP;
  	;SetI;
  	;regPC = (memory[0xfffb] << 8) | memory[0xfffa];
  	;regS = S;



;/*
;	==============================================================
;	The first switch statement is used to determine the addressing
;	mode, while the second switch implements the opcode. When I
;	have more confidence that these are working correctly they
;	will be combined into a single switch statement. At the
;	moment changes can be made very easily.
;	==============================================================
;*/

	section data
CYCLES:
	dc.w 7, 2, 0, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6
  	dc.w 2, 5, 0, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7
  	dc.w 6, 6, 0, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6
  	dc.w 2, 5, 0, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7

  	dc.w 6, 6, 0, 8, 3, 3, 7, 5, 3, 2, 2, 2, 3, 4, 6, 6
  	dc.w 2, 5, 0, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 0, 7
  	dc.w 6, 6, 0, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6
  	dc.w 2, 5, 0, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7

  	dc.w 2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4
  	dc.w 2, 6, 0, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5
  	dc.w 2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4
  	dc.w 2, 5, 0, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4

  	dc.w 2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6
  	dc.w 2, 5, 0, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7
  	dc.w 2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6
  	dc.w 2, 5, 0, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7



MODE_TABLE1:
;when we will call instruction straight, this table is used
;when we want to get byte, this table contains addr to GET BYTE routine
;when we want to put byte, this table contains addr to own command
;when we want to put and get byte (rol, ror, inc etc.), this routine is the same as in the case GET BYTE
;if the instruction take byte straight from command, this routine contains addr to own comman as well


	dc.l opcode_00, opcode_01, opcode_02, opcode_03
	;     brk         ora        illegal     illegal

	dc.l opcode_04,opcode_05,opcode_06, opcode_07
	;     nop         ora          asl        nop

	dc.l opcode_08,opcode_09,opcode_0a,opcode_0b
	;     php         ora        asla       illegal

	dc.l opcode_0c,opcode_0d,opcode_0e,opcode_0f
	;     nop 3       ora          asl      illegal

	dc.l opcode_10,opcode_11,  opcode_12, opcode_13
	;     bpl         ora        illegal    illegal

	dc.l opcode_14,opcode_15, opcode_16,  opcode_17
	;     nop         ora         asl       illegal

	dc.l opcode_18,opcode_19, opcode_1a,   opcode_1b
	;     clc         ora         nop       illegal

      	dc.l opcode_1c,opcode_1d,  opcode_1e, opcode_1f
	;     nop         ora        asl        illegal

      	dc.l opcode_20,opcode_21,opcode_22,  opcode_23
	;     jsr         and       illegal     illegal

      	dc.l opcode_24,opcode_25,opcode_26,opcode_27
	;     bit         and        rol        illegal

      	dc.l opcode_28, opcode_29,    opcode_2a,  opcode_2b
	;     plp        and         rolA      illegal

      	dc.l opcode_2c, opcode_2d, opcode_2e, opcode_2f
	;      bit       and         rol       illegal

      	dc.l opcode_30, opcode_31, opcode_32, opcode_33
	;      bmi       and        illegal     illegal

      	dc.l opcode_34, opcode_35, opcode_36, opcode_37
	;     nop        and         rol       illegal

      	dc.l opcode_38, opcode_39, opcode_3a, opcode_3b
	;      sec        and        nop        illegal

      	dc.l opcode_3c, opcode_3d, opcode_3e, opcode_3f
	;      nop         and       rol        illegal

      	dc.l opcode_40, opcode_41, opcode_42, opcode_43
            ;      rti        eor        illegal   illegal

      	dc.l opcode_44, opcode_45, opcode_46, opcode_47
	;      nop        eor        lsr       illegal

      	dc.l opcode_48, opcode_49, opcode_4a, opcode_4b
      	;      pha        eor        lsrA       illegal

      	dc.l opcode_4c, opcode_4d, opcode_4e, opcode_4f
	;      jmp        eor        lsr       illegal

      	dc.l opcode_50, opcode_51,  opcode_52, opcode_53
	;      bvc       eor        illegal     illegal

      	dc.l opcode_54, opcode_55, opcode_56, opcode_57
	;      nop        eor      lsr       illegal

      	dc.l opcode_58, opcode_59, opcode_5a, opcode_5b
	;      cli        eor      nop         illegal

      	dc.l opcode_5c, opcode_5d, opcode_5e, opcode_5f
	;      nop        eor        lsr        illegal

      	dc.l opcode_60, opcode_61, opcode_62, opcode_63
	;      rts        adc        illegal    illegal

      	dc.l opcode_64, opcode_65, opcode_66, opcode_67
	;      nop        adc        ror        illegal

      	dc.l opcode_68, opcode_69,opcode_6a,opcode_6b
	;      pla       adc         rorA       illegal

      	dc.l opcode_6c, opcode_6d, opcode_6e, opcode_6f
	;    jmp (abcd)   adc      ror          illegal

      	dc.l opcode_70, opcode_71, opcode_72, opcode_73
	;      bvs        adc      illegal    illegal

      	dc.l opcode_74, opcode_75, opcode_76, opcode_77
	;      nop         adc       ror       illegal

      	dc.l opcode_78, opcode_79, opcode_7a, opcode_7b
	;     SEI          adc        illegal   illegal

      	dc.l opcode_7c, opcode_7d, opcode_7e, opcode_7f
	;     nop          adc       ror        illegal

      	dc.l opcode_80, opcode_81, opcode_82, opcode_83
	;     nop          sta       nop        illegal

      	dc.l opcode_84, opcode_85, opcode_86,opcode_87
	;     sty	       sta       stx        illegal

      	dc.l opcode_88, opcode_89, opcode_8a, opcode_8b
	;     dey          nop        txa       illegal

      	dc.l opcode_8c, opcode_8d, opcode_8e, opcode_8f
	;     sty	       sta       stx        illegal

      	dc.l opcode_90, opcode_91, opcode_92, opcode_93
	;      bcc         sta       illegal    illegal

      	dc.l opcode_94, opcode_95, opcode_96, opcode_97
	;      sty       sta         stx        illegal

      	dc.l opcode_98, opcode_99, opcode_9a, opcode_9b
	;     tya        sta         txs         illegal

      	dc.l opcode_9c, opcode_9d, opcode_9e, opcode_9f
	;     illegal     sta         ilegal     illegal

      	dc.l opcode_a0,    opcode_a1, opcode_a2, opcode_a3
	;      ldy         lda        ldx        lax

      	dc.l opcode_a4, opcode_a5, opcode_a6, opcode_a7
	;     ldy        lda        ldx         lax

      	dc.l opcode_a8, opcode_a9,     opcode_aa, opcode_ab
 	;     tay         lda         tax      illegal

      	dc.l opcode_ac, opcode_ad, opcode_ae, opcode_af
	;      ldy         lda        ldx        lax

      	dc.l opcode_b0, opcode_b1, opcode_b2, opcode_b3
	;      bcs       lda         illegal    lax

      	dc.l opcode_b4, opcode_b5, opcode_b6, opcode_b7
	;      ldy        lda         ldx       lax

      	dc.l opcode_b8, opcode_b9, opcode_ba, opcode_bb
	;      clv         lda        tsx        illegal

      	dc.l opcode_bc, opcode_bd, opcode_be, opcode_bf
	;       ldy        lda         ldx           lax

      	dc.l opcode_c0, opcode_c1, opcode_c2, opcode_c3
	;    cpy          cmp         nop        illegal

      	dc.l opcode_c4, opcode_c5, opcode_c6, opcode_c7
	;     cpy         cmp       dec         illegal

      	dc.l opcode_c8, opcode_c9,  opcode_ca, opcode_cb
	;      iny       cmp       dex         illegal

      	dc.l opcode_cc, opcode_cd, opcode_ce, opcode_cf
	;     cpy        cmp        dec        illegal

      	dc.l opcode_d0, opcode_d1, opcode_d2, opcode_d3
	;      bne       cmp         escrts      illegal

      	dc.l opcode_d4, opcode_d5, opcode_d6, opcode_d7
	;     nop         cmp      dec         illegal

      	dc.l opcode_d8, opcode_d9, opcode_da, opcode_db
	;     cld         cmp          nop     illegal

      	dc.l opcode_dc, opcode_dd, opcode_de, opcode_df
	;      nop         cmp        dec       illegal

      	dc.l opcode_e0, opcode_e1, opcode_e2, opcode_e3
 	;     cpx         sbc        nop         nop

      	dc.l opcode_e4, opcode_e5, opcode_e6, opcode_e7
	;     cpx        sbc          inc        illegal

      	dc.l opcode_e8, opcode_e9,opcode_ea, opcode_eb
	;      inx       sbc           nop      illegal

      	dc.l opcode_ec, opcode_ed, opcode_ee, opcode_ef
	;       cpx      sbc          inc         illegal

	dc.l opcode_f0, opcode_f1, opcode_f2, opcode_f3
	;     beq          sbc        esc#ab     illegal

      	dc.l opcode_f4, opcode_f5, opcode_f6, opcode_f7
	;     nop          sbc        inc       illegal

      	dc.l opcode_f8, opcode_f9, opcode_fa, opcode_fb
	;     sed         sbc         nop         illegal

      	dc.l opcode_fc, opcode_fd, opcode_fe, opcode_ff
	;     nop         sbc          inc        esc#ab



MODE_TABLE2:
	dc.l opcode_00, INDIRECT_X, opcode_02, opcode_03
	;     brk         ora        illegal     illegal

	dc.l opcode_04,  ZPAGE,      ZPAGE,   opcode_07
	;     nop         ora          asl        nop

	dc.l opcode_08,  DIRECT,   opcode_0a, opcode_0b
	;     php         ora          asla     illegal

	dc.l opcode_0c, ABSOLUTE,   ABSOLUTE,  opcode_0f
	;     nop 3       ora          asl      illegal

	dc.l opcode_10, INDIRECT_Y, opcode_12, opcode_13
	;     bpl         ora        illegal    illegal

	dc.l opcode_14,   ZPAGE_X,   ZPAGE_X,  opcode_17
	;     nop         ora         asl       illegal

	dc.l opcode_18, ABSOLUTE_Y, opcode_1a, opcode_1b
	;     clc         ora         nop       illegal

      	dc.l opcode_1c, ABSOLUTE_X,ABSOLUTE_X, opcode_1f
	;     nop         ora        asl        illegal

      	dc.l opcode_20, INDIRECT_X,opcode_22,  opcode_23
	;     jsr         and       illegal     illegal

      	dc.l ZPAGE,      ZPAGE,    ZPAGE,      opcode_27
	;     bit         and        rol        illegal

      	dc.l opcode_28, DIRECT,    opcode_2a,  opcode_2b
	;     plp        and         rolA      illegal

       	dc.l ABSOLUTE, ABSOLUTE,   ABSOLUTE,   opcode_2f
	;      bit       and         rol       illegal

      	dc.l opcode_30, INDIRECT_Y, opcode_32, opcode_33
	;      bmi       and        illegal     illegal

      	dc.l opcode_34, ZPAGE_X,    ZPAGE_X, opcode_37
	;     nop        and         rol       illegal

      	dc.l opcode_38, ABSOLUTE_Y, opcode_3a, opcode_3b
	;      sec        and        nop        illegal

      	dc.l opcode_3c, ABSOLUTE_X, ABSOLUTE_X, opcode_3f
	;      nop         and       rol        illegal

      	dc.l opcode_40, INDIRECT_X, opcode_42, opcode_43
            ;      rti        eor        illegal   illegal

      	dc.l opcode_44,  ZPAGE,    ZPAGE,      opcode_47
	;      nop        eor        lsr       illegal

      	dc.l opcode_48, DIRECT,     opcode_4a, opcode_4b
      	;      pha        eor        lsrA       illegal

	dc.l opcode_4c, ABSOLUTE, ABSOLUTE,    opcode_4f
	;      jmp        eor        lsr       illegal

      	dc.l opcode_50, INDIRECT_Y,  opcode_52, opcode_53
	;      bvc       eor        illegal     illegal

      	dc.l opcode_54, ZPAGE_X,  ZPAGE_X, opcode_57
	;      nop        eor      lsr       illegal

      	dc.l opcode_58, ABSOLUTE_Y, opcode_5a, opcode_5b
	;      cli        eor      nop         illegal

      	dc.l opcode_5c, ABSOLUTE_X, ABSOLUTE_X, opcode_5f
	;      nop        eor        lsr        illegal

      	dc.l opcode_60, INDIRECT_X, opcode_62, opcode_63
	;      rts        adc        illegal    illegal

      	dc.l opcode_64, ZPAGE,      ZPAGE,     opcode_67
	;      nop        adc        ror        illegal

      	dc.l opcode_68, DIRECT,   opcode_6a,  opcode_6b
	;      pla       adc         rorA       illegal

      	dc.l opcode_6c, ABSOLUTE, ABSOLUTE,   opcode_6f
	;    jmp (abcd)   adc      ror          illegal

      	dc.l opcode_70, INDIRECT_Y, opcode_72, opcode_73
	;      bvs        adc      illegal    illegal

      	dc.l opcode_74,  ZPAGE_X,   ZPAGE_X,   opcode_77
	;      nop         adc       ror       illegal

      	dc.l opcode_78, ABSOLUTE_Y, opcode_7a, opcode_7b
	;     SEI          adc        illegal   illegal

      	dc.l opcode_7c, ABSOLUTE_X, ABSOLUTE_X, opcode_7f
	;     nop          adc       ror        illegal

      	dc.l opcode_80, INDIRECT_X, opcode_82, opcode_83
	;     nop          sta       nop        illegal

      	dc.l ZPAGE,     ZPAGE,      ZPAGE,     opcode_87
	;     sty	       sta       stx        illegal

      	dc.l opcode_88, opcode_89, opcode_8a, opcode_8b
	;     dey          nop        txa       illegal

      	dc.l ABSOLUTE,  ABSOLUTE,  ABSOLUTE, opcode_8f
	;     sty	       sta       stx        illegal

      	dc.l opcode_90, INDIRECT_Y, opcode_92, opcode_93
	;      bcc         sta       illegal    illegal

      	dc.l ZPAGE_X,   ZPAGE_X,   ZPAGE_Y, opcode_97
	;      sty       sta         stx        illegal


      	dc.l opcode_98, ABSOLUTE_Y, opcode_9a, opcode_9b
	;     tya        sta         txs         illegal

      	dc.l opcode_9c, ABSOLUTE_X, opcode_9e, opcode_9f
	;     illegal     sta         ilegal     illegal

      	dc.l DIRECT,    INDIRECT_X, DIRECT,    INDIRECT_X
	;      ldy         lda        ldx        lax

      	dc.l ZPAGE,     ZPAGE,     ZPAGE,      ZPAGE
	;     ldy        lda        ldx         lax

      	dc.l opcode_a8, DIRECT,     opcode_aa, opcode_ab
 	;     tay         lda         tax      illegal

      	dc.l ABSOLUTE, ABSOLUTE,   ABSOLUTE,   ABSOLUTE
	;      ldy         lda        ldx        lax

      	dc.l opcode_b0, INDIRECT_Y, opcode_b2, INDIRECT_Y
	;      bcs       lda         illegal    lax

      	dc.l ZPAGE_X,  ZPAGE_X,    ZPAGE_Y,    ZPAGE_Y
	;      ldy        lda         ldx       lax

      	dc.l opcode_b8, ABSOLUTE_Y, opcode_ba, opcode_bb
	;      clv         lda        tsx        illegal

      	dc.l ABSOLUTE_X, ABSOLUTE_X, ABSOLUTE_Y,  ABSOLUTE_Y
	;       ldy        lda         ldx           lax

      	dc.l DIRECT,    INDIRECT_X, opcode_c2, opcode_c3
	;    cpy          cmp         nop        illegal

      	dc.l ZPAGE,       ZPAGE,    ZPAGE,     opcode_c7
	;     cpy         cmp       dec         illegal

      	dc.l opcode_c8, DIRECT,  opcode_ca, opcode_cb
	;      iny       cmp       dex         illegal

      	dc.l ABSOLUTE,  ABSOLUTE, ABSOLUTE, opcode_cf
	;     cpy        cmp        dec        illegal

      	dc.l opcode_d0, INDIRECT_Y, opcode_d2, opcode_d3
	;      bne       cmp         escrts      illegal

      	dc.l opcode_d4, ZPAGE_X,    ZPAGE_X,   opcode_d7
	;     nop         cmp      dec         illegal


      	dc.l opcode_d8, ABSOLUTE_Y, opcode_da, opcode_db
	;     cld         cmp          nop     illegal

      	dc.l opcode_dc, ABSOLUTE_X, ABSOLUTE_X, opcode_df
	;      nop         cmp        dec       illegal

      	dc.l DIRECT,    INDIRECT_X, opcode_e2, opcode_e3
 	;     cpx         sbc        nop         nop

      	dc.l ZPAGE,    ZPAGE,       ZPAGE,     opcode_e7
	;     cpx        sbc          inc        illegal

      	dc.l opcode_e8, DIRECT,     opcode_ea, opcode_eb
	;      inx       sbc           nop      illegal

      	dc.l ABSOLUTE,  ABSOLUTE,   ABSOLUTE, opcode_ef
	;       cpx      sbc          inc         illegal

	dc.l opcode_f0, INDIRECT_Y, opcode_f2, opcode_f3
	;     beq          sbc        esc#ab     illegal

      	dc.l opcode_f4, ZPAGE_X,     ZPAGE_X,  opcode_f7
	;     nop          sbc        inc       illegal

      	dc.l opcode_f8, ABSOLUTE_Y, opcode_fa, opcode_fb
	;     sed         sbc         nop         illegal

      	dc.l opcode_fc, ABSOLUTE_X, ABSOLUTE_X, opcode_ff
	;     nop         sbc          inc        esc#ab




	section text

_GO: ;cycles (d0)


;  UWORD PC;
;  UBYTE S;
;  UBYTE A;
;  UBYTE X;
;  UBYTE Y;
;
;  UWORD	addr;
;  UBYTE	data;

;/*
;   This used to be in the main loop but has been removed to improve
;   execution speed. It does not seem to have any adverse effect on
;   the emulation for two reasons:-
;
;   1. NMI's will can only be raised in atari_custom.c - there is
;      no way an NMI can be generated whilst in this routine.
;
;   2. The timing of the IRQs are not that critical.
;*/

	movem.l d0-d7/a0-a6,-(a7)
	move.w 66(a7),CD ;write how much cycles (should be 6)
	lea _memory,memory_pointer
	UPDATE_LOCAL_REGS
	ConvertRegP_STATUS
	lea OPMODE_TABLE,a0
	lea _attrib,attrib_pointer
	tst.b _IRQ
	beq GET_FIRST_INSTRUCTION
	move.b _regP,d6
	and.b #I_FLAG,d6 ;is interrupt active
	bne GET_FIRST_INSTRUCTION ;yes, no other interrupt
_AIRQ:	move.w _regPC,d7     ;UAAAA :)	;write back addr
	LoHi
	move.w d7,-(stack_pointer)
	move.b _regP,-(stack_pointer)
	;PHP
	SetI
	clr.l d7
	move.w (memory_pointer,$fffe.l),d7
	LoHi
	move.l d7,PC6502
	add.l memory_pointer,PC6502
	clr.b _IRQ ;clear interrupt.....
	ifd SERVER
	move.w #-1,WAIT
	endc
	bra GET_FIRST_INSTRUCTION

END_OF_CYCLE:
	;move.l (a7)+,a1
	ConvertSTATUS_RegP
 	move.b d6,_regP
	UPDATE_GLOBAL_REGS
	movem.l (a7)+,d0-d7/a0-a6
	rts
ADRESA:	dc.l 1

  ;UPDATE_LOCAL_REGS

  ;if (IRQ)
  ;  {
  ;    if (!(regP & I_FLAG))
  ;	{
  ;	  UWORD retadr = PC;

  ;  memory[0x0100 + S--] = retadr >> 8;
  ;  memory[0x0100 + S--] = retadr & 0xff;
  ;  PHP;
  ;  SetI;
  ;  PC = (memory[0xffff] << 8) | memory[0xfffe];
  ;  IRQ = 0;
  ;	}
  ;  }



;/*
;   =====================================
;   Extract Address if Required by Opcode
;   =====================================
;*/

;d6 contains final value for use in program



ZPAGE_X
	move.l 4(a0,d7.l*8),d6
	move.b (PC6502)+,d7
	add.b X,d7
	subq.w #2,CD
	bra.s TEST


ZPAGE_Y
	move.l 4(a0,d7.l*8),d6
	move.b (PC6502)+,d7
	add.b Y,d7
	subq.w #2,CD
	bra.s TEST


ABSOLUTE_Y
	move.l 4(a0,d7.l*8),d6
	move.w (PC6502)+,d7
	ror.w #8,d7
	add.w Y,d7
	subq.w #2,CD
	bra.s TEST

INDIRECT_Y
	move.l 4(a0,d7.l*8),d6
	move.b (PC6502)+,d7
	move.w (memory_pointer,d7.l),d7
	ror.w #8,d7 ;swap bytes
	add.w Y,d7
	subq.w #4,CD
	bra.s TEST

ABSOLUTE_X
	move.l 4(a0,d7.l*8),d6
	move.w (PC6502)+,d7
	ror.w #8,d7
	add.w X,d7 ;add x to
	subq.w #2,CD
	bra.s TEST

INDIRECT_X
	move.l 4(a0,d7.l*8),d6
	move.b (PC6502)+,d7
	add.b X,d7
	move.w (memory_pointer,d7.l),d7
	ror.w #8,d7
	subq.w #4,CD
	bra.s TEST

ABSOLUTE:
	move.l 4(a0,d7.l*8),d6
	move.w (PC6502)+,d7
	ror.w #8,d7 ;d7 contains reversed value
	subq.w #2,CD
	bra.s TEST


ZPAGE:
	move.l 4(a0,d7.l*8),d6
	move.b (PC6502)+,d7 ;d6 contains offset
	subq.w #1,CD
	bra.s TEST

DIRECT:
	move.l 4(a0,d7.l*8),a1
	move.b (PC6502)+,d6
	jmp (a1)

TEST:	bclr #31,d6  ;get highest byte away
	bne.s JUST_WRITE
	move.l d6,a1
GONEBYTE:	;get one byte from memory
	tst.b (attrib_pointer,d7.l)
	bne.s JGetbyte
GZPAGEBYTE: ;get one byte from zero page
	move.b (memory_pointer,d7.l),d6 ;get byte
AFTER_READ:

JUMP_CODE:	jmp (a1)
JUST_WRITE:	move.l d6,a1
	jmp (a1) ;bra.s JUMP_CODE
JGetbyte:
	bra A800GETB


PUTONEBYTE_FL:
	move.b d6,NFLAG
	move.b d6,ZFLAG
PUTONEBYTE:	tst.b (attrib_pointer,d7.l)
	bne.s .Putbyte
	move.b d6,(memory_pointer,d7.l)
            goto NEXTCHANGE_WITHOUT

.Putbyte
	bra A800PUTB



;#define	ABSOLUTE	addr=(memory[PC+1]<<8)+memory[PC];PC+=2;
;#define	ZPAGE	addr=memory[PC++];
;#define	ABSOLUTE_X	addr=((memory[PC+1]<<8)+memory[PC])+(UWORD)X;PC+=2;
;#define 	ABSOLUTE_Y	addr=((memory[PC+1]<<8)+memory[PC])+(UWORD)Y;PC+=2;
;#define	INDIRECT_X	addr=(UWORD)memory[PC++]+(UWORD)X;addr=(memory[addr+1]<<8)+memory[addr];
;#define	INDIRECT_Y	addr=memory[PC++];addr=(memory[addr+1]<<8)+memory[addr]+(UWORD)Y;
;#define	ZPAGE_X	addr=(memory[PC++]+X)&0xff;
;#define	ZPAGE_Y	addr=(memory[PC++]+Y)&0xff;

BB


opcode_8d: ;/* STA abcd */
opcode_85: ;/* STA ab */
opcode_81: ;/* STA (ab,x) */
opcode_91: ;/* STA (ab),y */
opcode_95: ;/* STA ab,x */
opcode_99: ;/* STA abcd,y */
opcode_9d: ;/* STA abcd,x */
	move.b A,d6
	bra.s PUTONEBYTE
opcode_8e: ;/* STX abcd */
opcode_86: ;/* STX ab */
opcode_96: ;/* STX ab,y */
	move.b X,d6
	bra.s PUTONEBYTE
opcode_8c: ;/* STY abcd */
opcode_84: ;/* STY ab */
opcode_94: ;/* STY ab,x */
	move.b Y,d6
	bra.s PUTONEBYTE


opcode_e6: ;/* INC ab */
opcode_ee: ;/* INC abcd */
opcode_f6: ;/* INC ab,x */
opcode_fe: ;/* INC abcd,x */
	addq.b #2,d6 ;again funny piece of code

opcode_c6: ;/* DEC ab */
opcode_ce: ;/* DEC abcd */
opcode_d6: ;/* DEC ab,x */
opcode_de: ;/* DEC abcd,x */
	subq.b #1,d6
	bra.s PUTONEBYTE_FL ;put one byte with flags

opcode_0e: ;/* ASL abcd */
opcode_06: ;/* ASL ab */
opcode_16: ;/* ASL ab,x */
opcode_1e: ;/* ASL abcd,x */
	clr.w CCR6502
opcode_2e: ;/* ROL abcd */
opcode_36: ;/* ROL ab,x */
opcode_26: ;/* ROL ab */
opcode_3e: ;/* ROL abcd,x */
	move.w CCR6502,CCR
	addx.b d6,d6 ;left
	move.w CCR,CCR6502
	bra.s PUTONEBYTE_FL

opcode_46: ;/* LSR ab */
opcode_4e: ;/* LSR abcd */
opcode_56: ;/* LSR ab,x */
opcode_5e: ;/* LSR abcd,x */
	clr.w CCR6502

opcode_6e: ;/* ROR abcd */
opcode_66: ;/* ROR ab */
opcode_76: ;/* ROR ab,x */
opcode_7e: ;/* ROR abcd,x */
	move.w CCR6502,CCR
	roxr.b #1,d6
	move.w CCR,CCR6502
	bra.s PUTONEBYTE_FL

opcode_a9: ;/* LDA #ab */
opcode_a5: ;/* LDA ab */
opcode_a1: ;/* LDA (ab,x) */
opcode_ad: ;/* LDA abcd */
opcode_b1: ;/* LDA (ab),y */
opcode_b5: ;/* LDA ab,x */
opcode_b9: ;/* LDA abcd,y */
opcode_bd: ;/* LDA abcd,x */
	move.b d6,A
	bra.s NEXTCHANGE


opcode_a2: ;/* LDX #ab */
opcode_a6: ;/* LDX ab */
opcode_ae: ;/* LDX abcd */
opcode_b6: ;/* LDX ab,y */
opcode_be: ;/* LDX abcd,y */
	move.b d6,X
	bra.s NEXTCHANGE

opcode_a0: ;/* LDY #ab */
opcode_a4: ;/* LDY ab */
opcode_ac: ;/* LDY abcd */
opcode_b4: ;/* LDY ab,x */
opcode_bc: ;/* LDY abcd,x */
	move.b d6,Y
	bra.s NEXTCHANGE


opcode_e0: ;/* CPX #ab */
opcode_e4: ;/* CPX ab */
opcode_ec: ;/* CPX abcd */
	move.b X,NFLAG
	bra.s COMPARE

opcode_c0: ;/* CPY #ab */
opcode_c4: ;/* CPY ab */
opcode_cc: ;/* CPY abcd */
	move.b Y,NFLAG
	bra.s COMPARE

opcode_c1: ;/* CMP (ab,x) */
opcode_c5: ;/* CMP ab */
opcode_c9: ;/* CMP #ab */
opcode_cd: ;/* CMP abcd */
opcode_d1: ;/* CMP (ab),y */
opcode_d5: ;/* CMP ab,x */
opcode_d9: ;/* CMP abcd,y */
opcode_dd: ;/* CMP abcd,x */
	move.b A,NFLAG

COMPARE:	sub.b d6,NFLAG
	move.w CCR,CCR6502
	not.w CCR6502
	move.b NFLAG,ZFLAG
	bra.s NEXTCHANGE_WITHOUT ;without flags


opcode_29: ;/* AND #ab */
opcode_21: ;/* AND (ab,x) */
opcode_25: ;/* AND ab */
opcode_2d: ;/* AND abcd */
opcode_31: ;/* AND (ab),y */
opcode_35: ;/* AND ab,x */
opcode_39: ;/* AND abcd,y */
opcode_3d: ;/* AND abcd,x */
	and.b d6,A
	bra.s NEXTCHANGE_A ;change flags as A is set

opcode_49: ;/* EOR #ab */
opcode_41: ;/* EOR (ab,x) */
opcode_45: ;/* EOR ab */
opcode_4d: ;/* EOR abcd */
opcode_51: ;/* EOR (ab),y */
opcode_55: ;/* EOR ab,x */
opcode_59: ;/* EOR abcd,y */
opcode_5d: ;/* EOR abcd,x */
	eor.b d6,A
	bra.s NEXTCHANGE_A

opcode_09: ;/* ORA #ab */
opcode_01: ;/* ORA (ab,x) */
opcode_05: ;/* ORA ab */
opcode_0d: ;/* ORA abcd */
opcode_11: ;/* ORA (ab),y */
opcode_15: ;/* ORA ab,x */
opcode_19: ;/* ORA abcd,y */
opcode_1d: ;/* ORA abcd,x */
	or.b d6,A



;MAIN LOOP , where we are counting cycles and working with other STUFF


NEXTCHANGE_A: move.b A,d6
NEXTCHANGE:	move.b d6,ZFLAG
	move.b d6,NFLAG
NEXTCHANGE_WITHOUT:

	ifd C_BUGGING
	tst.w CD
	bmi ENDGO ;should be .S
	endc

	ifd SERVER
	UPDATE_GLOBAL_REGS
	ConvertSTATUS_RegP
	move.b d6,_regP
	tst.w WAIT
	bne STRAIGHT_GO ;if interrupt is active we won't test and will run until the end of interrupt is reached
	lea $400000,a1
.WAIT_FOR_DATA:
	cmp.l #$12345678,-16(a1)
	bne.s .WAIT_FOR_DATA
	move.b _regP,d6
	cmp.b -1(a1),d6
	bne.s .PRINT_OUT
	move.b _regS,d6
	cmp.b -2(a1),d6
	bne.s .PRINT_OUT
	move.b _regA,d6
	cmp.b -3(a1),d6
	bne.s .PRINT_OUT
	move.b _regX,d6
	cmp.b -4(a1),d6
	bne.s .PRINT_OUT
	move.b _regY,d6
	cmp.b -5(a1),d6
	bne.s .PRINT_OUT
	move.w _regPC,d6
	cmp.w -8(a1),d6
	bne.s .PRINT_OUT
	bra CONTINUE


.PRINT_OUT:

      movem.l a0-a6,-(a7)
      CPU_GetStatus
      jsr _tisk /*in atari c*/
      CPU_PutStatus
      movem.l (a7)+,a0-a6

CONTINUE:   lea $400000,a1
	move.l #'A800',-16(a1)

STRAIGHT_GO: ;interrupt is active, dont try trace....
      UPDATE_LOCAL_REGS
	endc

	ifd C_BUGGING
	move.l PC6502,A1
	sub.l a5,a1
	cmp.l _CEKEJ,a1
	bne.s CONT
_ADRESA:	nop
	ifd DEBUG
	illegal
	endc
	endc

CONT:	;move.l a1,-(a7)
            subq.w #2,CD
	tst.w CD
	bmi.s ENDGO
GET_FIRST_INSTRUCTION:
****************************************
	ifd BREAKING		following block of code allows you to enter
	move ccr,-(sp)		a break address in monitor
	move.l PC6502,d7
	sub.l memory_pointer,d7
	cmp.w _break_addr,d7
	bne.s   .get_first
	move.b #$ff,d7
	move (sp)+,ccr
          bsr odskoc_si		on break monitor is invoked
	move ccr,-(sp)

.get_first
	move (sp)+,ccr
	endc
****************************************
	clr.l d7
	move.b (PC6502)+,d7
	;move.w 4(a0,d7.l*8),d6
JUMPMODE:	jmp ([a0,d7.l*8])
ENDGO: 	bra END_OF_CYCLE  ;the end of cycle

opcode_0a: ;/* ASLA */
	clr.w CCR6502

opcode_2a: ;/* ROLA */
	move.w CCR6502,CCR
	addx.b A,A  ;rolx #1,A
	move.w CCR,CCR6502
	bra NEXTCHANGE_A

opcode_4a: ;/* LSRA */
	clr.w CCR6502

opcode_6a: ;/* RORA */
	move.w CCR6502,CCR
	roxr.b #1,A
	move.w CCR,CCR6502
	bra NEXTCHANGE_A


opcode_90: ;/* BCC */
	btst #EB68,CCR6502
	beq.s SOLVE
	bra.s NOTHING

opcode_b0: ;/* BCS */
	btst #EB68,CCR6502
	bne.s SOLVE
	bra.s NOTHING


opcode_f0: ;/* BEQ */
	tst.b ZFLAG
	beq.s SOLVE
	bra.s NOTHING

opcode_d0: ;/* BNE */
	tst.b ZFLAG
	beq.s NOTHING

SOLVE:
	move.b (PC6502)+,d7
      	extb.l d7
      	add.l d7,PC6502
      	;lea (PC6502,d7.l),PC6502
      	bra NEXTCHANGE_WITHOUT
NOTHING:	addq.l #1,PC6502
	bra NEXTCHANGE_WITHOUT


opcode_ca: ;/* DEX */  ;funny code DEX(-2)+1
	subq.b #2,X

opcode_e8: ;/* INX */
	addq.b #1,X
	move.b X,d6
	bra NEXTCHANGE

opcode_88: ;/* DEY */ ;funny code (DEY(-2)+1
	subq.b #2,Y

opcode_c8: ;/* INY */
	addq.b #1,Y
	move.b Y,d6
	bra NEXTCHANGE

opcode_a8: ;/* TAY */
      move.b A,Y
opcode_98: ;/* TYA */
      move.b Y,A
      bra NEXTCHANGE_A

opcode_aa: ;/* TAX */
      move.b A,X
opcode_8a: ;/* TXA */
      move.b X,A
      bra NEXTCHANGE_A

opcode_20: ;/* JSR abcd */
      move.l PC6502,d7 ;current pointer
      sub.l memory_pointer,d7
      addq.l #1,d7 ;back addres
      LoHi ;(it puts result into d6)
      move.w d7,-(stack_pointer)
opcode_4c: ;/* JMP abcd */
      move.w (PC6502)+,d7
      LoHi ;(in d7 adress where we want to jump)
      lea (memory_pointer,d7.l),PC6502
      ;add.l d7,PC6502
      subq.w #4,CD
      goto NEXTCHANGE_WITHOUT


opcode_60: ;/* RTS */
      move.w (stack_pointer)+,d7
      LoHi
      lea 1(memory_pointer,d7.l),PC6502
      ;addq.l #1,PC6502
      subq.w #4,CD
      goto NEXTCHANGE_WITHOUT

opcode_50: ;/* BVC */
	btst #V_FLAGB,_regP
	beq.s SOLVE
	bra.s NOTHING

opcode_70: ;/* BVS */
	btst #V_FLAGB,_regP
	bne.s SOLVE
	bra.s NOTHING

opcode_10: ;/* BPL */
	and.b #N_FLAG,NFLAG
	beq.s SOLVE
	bra.s NOTHING

opcode_30: ;/* BMI */
	and.b #N_FLAG,NFLAG
	bne.s SOLVE
	bra.s NOTHING


opcode_24: ;/* BIT ab */
opcode_2c: ;/* BIT abcd */
	move.b d6,NFLAG
	btst #V_FLAGB,d6
	beq.s .UNSET
	bset #V_FLAGB,_regP
	move.b A,ZFLAG
	and.b NFLAG,ZFLAG
	bra NEXTCHANGE_WITHOUT
.UNSET:
	bclr #V_FLAGB,_regP
	move.b A,ZFLAG
	and.b NFLAG,ZFLAG
	bra NEXTCHANGE_WITHOUT



opcode_40: ;/* RTI */
_RTI:
      PLP
      move.w (stack_pointer)+,d7
      LoHi
      lea (memory_pointer,d7.l),PC6502
      subq.w #4,CD
      ifd SERVER
      clr.w WAIT
      endc
      goto NEXTCHANGE_WITHOUT


opcode_61: ;/* ADC (ab,x) */
opcode_65: ;/* ADC ab */
opcode_69: ;/* ADC #ab */
opcode_6d: ;/* ADC abcd */
opcode_71: ;/* ADC (ab),y */
opcode_75: ;/* ADC ab,x */
opcode_79: ;/* ADC abcd,y */
opcode_7d: ;/* ADC abcd,x */
adc:

;/* ADC */
;    unsigned int temp = src + AC + (IF_CARRY() ? 1 : 0);
;    SET_ZERO(temp & 0xff);	/* This is not valid in decimal mode */
;    if (IF_DECIMAL()) {
;        if (((AC & 0xf) + (src & 0xf) + (IF_CARRY() ? 1 : 0)) > 9) temp += 6;
;	SET_SIGN(temp);
;	SET_OVERFLOW(!((AC ^ src) & 0x80) && ((AC ^ temp) & 0x80));
;	if (temp > 0x99) temp += 96;
;	SET_CARRY(temp > 0x99);
;    } else {
;	SET_SIGN(temp);
;	SET_OVERFLOW(!((AC ^ src) & 0x80) && ((AC ^ temp) & 0x80));
;	SET_CARRY(temp > 0xff);
;    }
;    AC = ((BYTE) temp);

	;addq.l #1,AAAAA
     	btst #D_FLAGB,_regP
	bne.s BDC_ADC

	move.w CCR6502,CCR
	addx.b d6,A ;data are added with carry (in 68000 Extended bit in this case)
	move.w CCR,CCR6502
	svs d6
	and.b #V_FLAG,d6
*	and.b #-V_FLAG,_regP
	and.b #~V_FLAG,_regP
	or.b d6,_regP
	bra NEXTCHANGE_A


	;if (!(regP & D_FLAG))
	;{
	;  UWORD	temp;
            ;  UWORD t_data;

            ;t_data = (UWORD)data + (UWORD)C;
	;Z = N = temp = (UWORD)A + t_data;
            ;V = (~(A ^ t_data)) & (Z ^ A) & 0x80; ;cruel construction :((

	;C = temp >> 8;
	;A = Z;
	;}
BDC_ADC:
	move.b CCR6502,CCR
	ori.b #4,CCR ; set zero flag
	abcd d6,A
	move.b CCR,CCR6502  ;V flag isn't soluted
	bra NEXTCHANGE_A


      	;else
	;{
	; int	bcd1, bcd2;

	; bcd1 = BCDtoDEC[A];
	; bcd2 = BCDtoDEC[data];

	; bcd1 += bcd2 + C;

	; Z = N = DECtoBCD[bcd1];

	; V = (Z ^ A) & 0x80;
	; C = (bcd1 > 99);
	; A = Z;
	;}
	;goto next;


opcode_e1: ;/* SBC (ab,x) */
opcode_e5: ;/* SBC ab */
opcode_e9: ;/* SBC #ab */
opcode_ed: ;/* SBC abcd */
opcode_f1: ;/* SBC (ab),y */
opcode_f5: ;/* SBC ab,x */
opcode_f9: ;/* SBC abcd,y */
opcode_fd: ;/* SBC abcd,x */

sbc:
;/* SBC */
;    unsigned int temp = AC - src - (IF_CARRY() ? 0 : 1);
;    SET_SIGN(temp);
;    SET_ZERO(temp & 0xff);	/* Sign and Zero are invalid in decimal mode */
;    SET_OVERFLOW(((AC ^ temp) & 0x80) && ((AC ^ src) & 0x80));
;    if (IF_DECIMAL()) {
;	if ( ((AC & 0xf) - (IF_CARRY() ? 0 : 1)) < (src & 0xf)) /* EP */ temp -= 6;
;	if (temp > 0x99) temp -= 0x60;
;    }
;    SET_CARRY(temp < 0x100);
;    AC = (temp & 0xff);



 	;addq.l #1,AAAAA
	btst #D_FLAGB,_regP
	bne.s BDC_SBC

	not.w CCR6502 ;change it????
	move.w CCR6502,CCR
	subx.b d6,A
	move.w CCR,CCR6502
	svs d6
	not.w CCR6502
	and.b #V_FLAG,d6
*	and.b #-V_FLAG,_regP
	and.b #~V_FLAG,_regP
	or.b d6,_regP
	bra NEXTCHANGE_A


      	;if (!(regP & D_FLAG))
	;{
	; UWORD	temp;
            ; UWORD t_data;

            ;t_data = (UWORD)data + (UWORD)!C;
	;temp = (UWORD)A - t_data;

	;Z = N = temp & 0xff;


;/*
; * This was the old code that I have been using upto version 0.5.2
; *  C = (A < ((UWORD)data + (UWORD)!C)) ? 0 : 1;
; */
;	  V = (~(A ^ t_data)) & (Z ^ A) & 0x80;
;	  C = (temp > 255) ? 0 : 1;
;	  A = Z;
;	}

BDC_SBC:
	not.w CCR6502 ;change it ?????
	move.b CCR6502,CCR
	ori.b #4,CCR ; set zero flag
	sbcd d6,A
	move.b CCR,CCR6502  ;V flag isn't soluted
	not.w CCR6502
	goto NEXTCHANGE_A


      	;else
	;{
	;  int	bcd1, bcd2;
	;
	;  bcd1 = BCDtoDEC[A];
	;  bcd2 = BCDtoDEC[data];

	;  bcd1 = bcd1 - bcd2 - !C;

	;  if (bcd1 < 0) bcd1 = 100 - (-bcd1);
	;  Z = N = DECtoBCD[bcd1];

	;  C = (A < (data + !C)) ? 0 : 1;
	;  V = (Z ^ A) & 0x80;
	;  A = Z;
	;}
      	;goto next;


opcode_68: ;/* PLA */
      move.b (stack_pointer)+,A
      subq.w #1,CD
      bra NEXTCHANGE_A


opcode_08: ;/* PHP */
      PHP
      subq.w #1,CD
      bra NEXTCHANGE_WITHOUT


opcode_48: ;/* PHA */
      move.b A,-(stack_pointer)
      subq.w #1,CD
      bra NEXTCHANGE_WITHOUT



opcode_28: ;/* PLP */
      PLP
      subq.w #1,CD
	bra NEXTCHANGE_WITHOUT

opcode_18: ;/* CLC */
      	clr.w CCR6502
	bra NEXTCHANGE_WITHOUT

opcode_38: ;/* SEC */
	moveq.w #-1,CCR6502
	bra NEXTCHANGE_WITHOUT

opcode_58: ;/* CLI */
	ClrI
	bra NEXTCHANGE_WITHOUT


opcode_d8: ;/* CLD */
	ClrD
	bra NEXTCHANGE_WITHOUT

opcode_b8: ;/* CLV */
	bclr.b #V_FLAGB,_regP
	bra NEXTCHANGE_WITHOUT

opcode_6c: ;/* JMP (abcd) */
      	move.w (PC6502)+,d7
      	LoHi
      	move.w (memory_pointer,d7.l),d7
      	LoHi
      	lea (memory_pointer,d7.l),PC6502
      	subq.w #5,CD
	bra NEXTCHANGE_WITHOUT

opcode_78: ;/* SEI */
      	SetI
	bra NEXTCHANGE_WITHOUT

opcode_f8: ;/* SED */
      	SetD
	bra NEXTCHANGE_WITHOUT

opcode_9a: ;/* TXS */
      	lea (memory_pointer,X.w),stack_pointer
      	lea $101(stack_pointer),stack_pointer
	bra NEXTCHANGE_WITHOUT

opcode_ba: ;/* TSX */
      	move.l stack_pointer,X
      	sub.l memory_pointer,X
      	sub.l #$101,X ;HIHIHI :) 3rd discovered error in last 30 hours....
      	       ;this one is because logic of STACK on 6502 4th error in 32 hours :)
	move.b X,d6
      	bra NEXTCHANGE



opcode_0c: ;/* NOP (3 bytes) [unofficial] */
opcode_3c:
opcode_5c:
opcode_7c:
opcode_dc:
opcode_fc:

      addq.l #1,PC6502
      subq.w #3,CD



opcode_04: ;/* NOP (2 bytes) [unofficial] */
opcode_14:
opcode_1c:
opcode_34:
opcode_44:
opcode_54:
opcode_64:
opcode_74:
opcode_80:
opcode_82:
opcode_89:
opcode_c2:
opcode_d4:
opcode_e2:
opcode_f4:

      addq.l #1,PC6502
      subq.w #3,CD

opcode_1a: ;/* NOP (1 byte) [unofficial] */
opcode_3a:
opcode_5a:
opcode_7a:
opcode_da:
opcode_fa:
opcode_ea: ;/* NOP */ ;oficial
	goto NEXTCHANGE_WITHOUT

opcode_d2: ;/* ESCRTS #ab (JAM) */
      move.b (PC6502)+,d7
      UPDATE_GLOBAL_REGS
      movem.l a0-a6,-(a7)
      CPU_GetStatus
      move.l d7,-(a7)
      jsr _Escape /*in atari c*/
      addq.l #4,a7
      CPU_PutStatus
      movem.l (a7)+,a0-a6
      UPDATE_LOCAL_REGS
      move.w (stack_pointer)+,d7
      LoHi
      lea (memory_pointer,d7.l),PC6502
      addq.l #1,PC6502
      bra GET_FIRST_INSTRUCTION

opcode_f2: ;/* ESC #ab (JAM) */
opcode_ff: ;/* ESC #ab */
      move.b (PC6502)+,d7
      UPDATE_GLOBAL_REGS
      movem.l a0-a6,-(a7)
      CPU_GetStatus
      move.l d7,-(a7)
      jsr _Escape
      addq.l #4,a7
      CPU_PutStatus
      movem.l (a7)+,a0-a6
      UPDATE_LOCAL_REGS
      bra GET_FIRST_INSTRUCTION




opcode_a3: ;/* LAX (ind,x) [unofficial] */
      ;INDIRECT_X
      ;GetByte d7
      move.b d7,A
      move.b d7,X
      move.b A,NFLAG
      move.b A,ZFLAG
      bra NEXTCHANGE_WITHOUT




opcode_a7: ;/* LAX zpage [unofficial] */
      ;ZPAGE
      ;GetByte d7
      move.b d7,A
      move.b d7,X
      move.b A,NFLAG
      move.b A,ZFLAG
      bra NEXTCHANGE_WITHOUT





opcode_af: ;/* LAX absolute [unofficial] */
      ;ABSOLUTE
      ;GetByte d7
      move.b d7,X
      move.b d7,A
      move.b A,NFLAG
      move.b A,ZFLAG
      bra NEXTCHANGE_WITHOUT



opcode_b3: ;/* LAX (ind),y [unofficial] */
      ;INDIRECT_Y
      ;GetByte d7
      move.b d7,A
      move.b d7,X
      move.b A,NFLAG
      move.b A,ZFLAG
      bra NEXTCHANGE_WITHOUT



opcode_b7: ;/* LAX zpage,y [unofficial] */
      ;ZPAGE_Y
      ;GetByte d7
      move.b d7,A
      move.b d7,X
      move.b A,NFLAG
      move.b A,ZFLAG
      bra NEXTCHANGE_WITHOUT

opcode_bf: ;/* LAX absolute,y [unofficial] */
      ;ABSOLUTE_Y
      ;GetByte d7
      move.b d7,A
      move.b d7,X
      move.b X,ZFLAG
      move.b X,NFLAG
      bra NEXTCHANGE_WITHOUT









opcode_02:
opcode_03:
opcode_07:
opcode_0b:
opcode_0f:
opcode_12:
opcode_13:
opcode_17:
opcode_1b:
opcode_1f:
opcode_22:
opcode_23:
opcode_27:
opcode_2b:
opcode_2f:
opcode_32:
opcode_33:
opcode_37:
opcode_3b:
opcode_3f:
opcode_42:
opcode_43:
opcode_47:
opcode_4b:
opcode_4f:
opcode_52:
opcode_53:
opcode_57:
opcode_5b:
opcode_5f:
opcode_62:
opcode_63:
opcode_67:
opcode_6b:
opcode_6f:
opcode_72:
opcode_73:
opcode_77:
opcode_7b:
opcode_7f:
opcode_83:
opcode_87:
opcode_8b:
opcode_8f:
opcode_92:
opcode_93:
opcode_97:
opcode_9b:
opcode_9c:
opcode_9e:
opcode_9f:
opcode_ab:
opcode_b2:
opcode_bb:
opcode_c3:
opcode_c7:
opcode_cb:
opcode_cf:
opcode_d3:
opcode_d7:
opcode_db:
opcode_df:
opcode_e3:
opcode_e7:
opcode_eb:
opcode_ef:
opcode_f3:
opcode_f7:
opcode_fb:
	;pea text(pc)
	;move.w #9,-(a7)
	;trap #1
	;addq.l #1,ILEGALY
	;illegal
	bra NEXTCHANGE_WITHOUT
ILEGALY:	dc.l 0
text:	dc.b 'NEJAKA CHYBA TY BLBE'
	even

UPDATE_GLOBAL_REGS

      ;printf ("*** Invalid Opcode %02x at address %04x\n",
      ;	      memory[PC-1], PC-1);
      ;ncycles = 0;
      ;break;

opcode_00: ;/* BRK */
      btst #I_FLAGB,_regP
      bne NEXTCHANGE_WITHOUT
      move.l PC6502,d7
      sub.l memory_pointer,d7
      addq.w #1,d7
      LoHi
      move.w d7,-(stack_pointer)
      SetB
      PHP
      SetI
      move.w (memory_pointer,$fffe.l),d7
      LoHi
      move.l d7,PC6502
      add.l memory_pointer,PC6502
      subq.w #5,CD
      bra NEXTCHANGE_WITHOUT



A800GETB:
	cmp.b #1,(attrib_pointer,d7.l)
	beq.s .READ_FROM_ROM
	movem.l a0/a1/a6/d0/d1,-(a7)
	move.l d7,-(a7)
	jsr _GETBYTE
	move.w d0,d6 ;put stack onto right place
	addq.l #4,a7
	movem.l (a7)+,a0/a1/a6/d0/d1
	bra AFTER_READ

.READ_FROM_ROM:
	move.b (memory_pointer,d7.l),d6
	bra AFTER_READ

	ifd DEBUG
_GETBYTE:	move.b (memory_pointer,d7.l),d6
	rts
	endc

; I used to be really stupid about stacking in C :))
; I believed that I have to push onto stack every time I call
; C function all registers, Fortunately I don't have to, d0-d1 and a0-a1 is enough

A800PUTB:
	cmp.b #1,(attrib_pointer,d7.l)
	beq.s .DONT_WRITE_TO_ROM

	move.l a0,-(a7)
	move.w d0,-(a7)
	move.w d1,-(a7)
	move.w a6,-(a7)
	;movem.l a0/a6/d0/d1,-(a7)
	clr.l -(a7)
	move.b d6,3(a7) ;byte
	move.l d7,-(a7) ;adress
	jsr _PUTBYTE
	move.w d0,d6 ;put value onto right place
	addq.l #8,a7
	;movem.l (a7)+,a0/a6/d0/d1
	move.w (a7)+,a6
	move.w (a7)+,d1
	move.w (a7)+,d0
	move.l (a7)+,a0
	tst.w d6
	bne ENDGO
	bra NEXTCHANGE_WITHOUT

.DONT_WRITE_TO_ROM:
	bra NEXTCHANGE_WITHOUT

	ifd DEBUG
_PUTBYTE:	move.b d6,(memory_pointer,d7.l)
	endc

odskoc_si:
      UPDATE_GLOBAL_REGS
      movem.l a0-a6,-(a7)
      CPU_GetStatus
      move.l d7,-(a7)
      jsr _Escape
      addq.l #4,a7
      CPU_PutStatus
      movem.l (a7)+,a0-a6
      UPDATE_LOCAL_REGS
      rts

	ifd DEBUG
_CEKEJ:	dc.l 1
	endc

EE:	dc.w 0
WAIT:	dc.w 0

	section bss
_OPMODE_TABLE:
	ds.w 1
OPMODE_TABLE: ds.l 514 (2*256 long words)+2 as a reserve


	ifnd DEBUG
LE:	ds.l 1
STACKALL:   ds.l 16
	endc

	ifd DEBUG
	section data
;VBDIFLAG:	dc.w 1 ;information about CCR bits V B D I
	dc.l 0
	dc.l 0 ;
mem6502:	;dc.l MEMORY

	;ds.w 1
memory:
_memory:

	ds.b 40960
	incbin H:\ATARI800\ATARIBAS.ROM ;load basic
	incbin H:\ATARI800\ATARIXL.ROM  ;load Atari XL

	ds.b 8192
	dc.b $a9,50,$69,90,$e9,40,$20,$4c,00,20

	dc.b $a9,$00,$a2,0,$a0,0
	;lda #0, ldx #0, ldy #0
	dc.b $a5,$06,$ae,$1,$1,$bc,2,2
	;lda $06 ldx $0101 ldy $0202,x
	dc.b $a1,02,$a6,2,$b4,2
	;lda (2,x) ldx 2 ldy 2,x
	dc.b $81,0,$8e,01,01,$94,22
	;   sta (0,x) stx $0101 sty 22,y
	dc.b $e6,10,$6e,05,05,$e0,10
	;   INC 10, ROR 0505 CPX #10
	dc.b $4c,0,$20
;PL:	ds.b 65536-(PL-memory)


attrib:
_attrib:	dcb.b $A000,RAM
	dcb.b  $2000,ROM
	dcb.b  $1000,HARDWARE
	dcb.b  $3000,ROM
	;dc.b ROM
	;dc.b ROM
	;dc.b ROM
	;dcb.b 16383,RAM
	;65536,RAM ;set all the memory as RAM

	section bss
TEST2:	ds.l 20000
	section text
_Escape:	rts
	endc
	section text