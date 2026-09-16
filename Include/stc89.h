#ifndef STC89_H
#define STC89_H

#include "compiler.h"

#ifdef REG8051_H
#undef REG8051_H
#endif

SFR(P0, 0x80);
    SBIT(P0_0, 0x80, 0);
    SBIT(P0_1, 0x80, 1);
    SBIT(P0_2, 0x80, 2);
    SBIT(P0_3, 0x80, 3);
    SBIT(P0_4, 0x80, 4);
    SBIT(P0_5, 0x80, 5);
    SBIT(P0_6, 0x80, 6);
    SBIT(P0_7, 0x80, 7);

SFR(SP,   0x81);
SFR(DPL,  0x82);
SFR(DPH,  0x83);
SFR(PCON, 0x87);

SFR(TCON, 0x88);
    SBIT(TF1, 0x88, 7);
    SBIT(TR1, 0x88, 6);
    SBIT(TF0, 0x88, 5);
    SBIT(TR0, 0x88, 4);
    SBIT(IE1, 0x88, 3);
    SBIT(IT1, 0x88, 2);
    SBIT(IE0, 0x88, 1);
    SBIT(IT0, 0x88, 0);

SFR(TMOD, 0x89);
SFR(TL0,  0x8A);
SFR(TL1,  0x8B);
SFR(TH0,  0x8C);
SFR(TH1,  0x8D);
SFR(AUXR, 0x8E);

SFR(P1, 0x90);
    SBIT(P1_0, 0x90, 0);
    SBIT(P1_1, 0x90, 1);
    SBIT(P1_2, 0x90, 2);
    SBIT(P1_3, 0x90, 3);
    SBIT(P1_4, 0x90, 4);
    SBIT(P1_5, 0x90, 5);
    SBIT(P1_6, 0x90, 6);
    SBIT(P1_7, 0x90, 7);

    SBIT(T2EX, 0x90, 1);
    SBIT(T2,   0x90, 0);

SFR(SCON, 0x98);
    SBIT(SM0, 0x98, 7);
    SBIT(SM1, 0x98, 6);
    SBIT(SM2, 0x98, 5);
    SBIT(REN, 0x98, 4);
    SBIT(TB8, 0x98, 3);
    SBIT(RB8, 0x98, 2);
    SBIT(TI,  0x98, 1);
    SBIT(RI,  0x98, 0);

SFR(SBUF, 0x99);

SFR(P2, 0xA0);
    SBIT(P2_0, 0xA0, 0);
    SBIT(P2_1, 0xA0, 1);
    SBIT(P2_2, 0xA0, 2);
    SBIT(P2_3, 0xA0, 3);
    SBIT(P2_4, 0xA0, 4);
    SBIT(P2_5, 0xA0, 5);
    SBIT(P2_6, 0xA0, 6);
    SBIT(P2_7, 0xA0, 7);

SFR(AUXR1, 0xA2);

SFR(IE, 0xA8);
    SBIT(EA,  0xA8, 7);
    SBIT(EC,  0xA8, 6);
    SBIT(ET2, 0xA8, 5);
    SBIT(ES,  0xA8, 4);
    SBIT(ET1, 0xA8, 3);
    SBIT(EX1, 0xA8, 2);
    SBIT(ET0, 0xA8, 1);
    SBIT(EX0, 0xA8, 0);

SFR(SADDR, 0xA9);

SFR(P3, 0xB0);
    SBIT(P3_0, 0xB0, 0);
    SBIT(P3_1, 0xB0, 1);
    SBIT(P3_2, 0xB0, 2);
    SBIT(P3_3, 0xB0, 3);
    SBIT(P3_4, 0xB0, 4);
    SBIT(P3_5, 0xB0, 5);
    SBIT(P3_6, 0xB0, 6);
    SBIT(P3_7, 0xB0, 7);

    SBIT(RD,   0xB0, 7);
    SBIT(WR,   0xB0, 6);
    SBIT(T1,   0xB0, 5);
    SBIT(T0,   0xB0, 4);
    SBIT(INT1, 0xB0, 3);
    SBIT(INT0, 0xB0, 2);
    SBIT(TXD,  0xB0, 1);
    SBIT(RXD,  0xB0, 0);

SFR(IPH, 0xB7);
SFR(IP, 0xB8);
    SBIT(PT2, 0xB8, 5);
    SBIT(PS,  0xB8, 4);
    SBIT(PT1, 0xB8, 3);
    SBIT(PX1, 0xB8, 2);
    SBIT(PT0, 0xB8, 1);
    SBIT(PX0, 0xB8, 0);

SFR(SADEN, 0xB9);

SFR(XICON, 0xC0);
    SBIT(PX3, 0xC0, 7);
    SBIT(EX3, 0xC0, 6);
    SBIT(IE3, 0xC0, 5);
    SBIT(IT3, 0xC0, 4);
    SBIT(PX2, 0xC0, 3);
    SBIT(EX2, 0xC0, 2);
    SBIT(IE2, 0xC0, 1);
    SBIT(IT2, 0xC0, 0);

SFR(T2CON, 0xC8);
    SBIT(TF2,    0xC8, 7);
    SBIT(EXF2,   0xC8, 6);
    SBIT(RCLK,   0xC8, 5);
    SBIT(TCLK,   0xC8, 4);
    SBIT(EXEN2,  0xC8, 3);
    SBIT(TR2,    0xC8, 2);
    SBIT(C_T2,   0xC8, 1);
    SBIT(CP_RL2, 0xC8, 0);

SFR(T2MOD,  0xC9);
SFR(RCAP2L, 0xCA);
SFR(RCAP2H, 0xCB);
SFR(TL2,    0xCC);
SFR(TH2,    0xCD);

SFR(PSW, 0xD0);
    SBIT(CY,  0xD0, 7);
    SBIT(AC,  0xD0, 6);
    SBIT(F0,  0xD0, 5);
    SBIT(RS1, 0xD0, 4);
    SBIT(RS0, 0xD0, 3);
    SBIT(OV,  0xD0, 2);
    SBIT(F1,  0xD0, 1);
    SBIT(P,   0xD0, 0);

SFR(ACC, 0xE0);

SFR(WDT_CONTR, 0xE1);
SFR(IAP_DATA,  0xE2);
SFR(IAP_ADDRH, 0xE3);
SFR(IAP_ADDRL, 0xE4);
SFR(IAP_CMD,   0xE5);
SFR(IAP_TRIG,  0xE6);
SFR(IAP_CONTR, 0xE7);

SFR(P4, 0xE8);
    SBIT(P4_0, 0xE8, 0);
    SBIT(P4_1, 0xE8, 1);
    SBIT(P4_2, 0xE8, 2);
    SBIT(P4_3, 0xE8, 3);
    SBIT(P4_4, 0xE8, 4);
    SBIT(P4_5, 0xE8, 5);
    SBIT(P4_6, 0xE8, 6);
    SBIT(P4_7, 0xE8, 7);

SFR(B, 0xF0);

#endif /* STC89_H */
