
#include "atari.h"

#define N_FLAG 0x80
#define V_FLAG 0x40
#define G_FLAG 0x20
#define B_FLAG 0x10
#define D_FLAG 0x08
#define I_FLAG 0x04
#define Z_FLAG 0x02
#define C_FLAG 0x01

void CPU_GetStatus(void);
void CPUGET(void);				/*put from CCR, N & Z FLAG into regP */
/*void CPU_PutStatus (void); */
void CPU_Reset(void);
void SetRAM(int addr1, int addr2);
void SetROM(int addr1, int addr2);
void SetHARDWARE(int addr1, int addr2);
extern void NMI(void);
extern void GO(int cycles);
extern void CPU_INIT(void);

extern UWORD regPC;
extern UBYTE regA;
extern UBYTE regP;
extern UBYTE regS;
extern UBYTE regY;
extern UBYTE regX;

#define SetN regP|=N_FLAG
#define ClrN regP&=(~N_FLAG)
#define SetV regP|=V_FLAG
#define ClrV regP&=(~V_FLAG)
#define SetB regP|=B_FLAG
#define ClrB regP&=(~B_FLAG)
#define SetD regP|=D_FLAG
#define ClrD regP&=(~D_FLAG)
#define SetI regP|=I_FLAG
#define ClrI regP&=(~I_FLAG)
#define SetZ regP|=Z_FLAG
#define ClrZ regP&=(~Z_FLAG)
#define SetC regP|=C_FLAG
#define ClrC regP&=(~C_FLAG)

extern UBYTE memory[65536];

extern UBYTE IRQ;