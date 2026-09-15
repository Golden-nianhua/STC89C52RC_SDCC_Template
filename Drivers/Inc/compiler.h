/*-------------------------------------------------------------------------
   compiler.h

   Copyright (C) 2006, Maarten Brock, sourceforge.brock@dse.nl
   Portions of this file are Copyright 2014 Silicon Laboratories, Inc.
   http://developer.silabs.com/legal/version/v11/Silicon_Labs_Software_License_Agreement.txt

   This library is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the
   Free Software Foundation; either version 2, or (at your option) any
   later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this library; see the file COPYING. If not, write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
   MA 02110-1301, USA.

   As a special exception, if you link this library with other files,
   some of which are compiled with SDCC, to produce an executable,
   this library does not by itself cause the resulting executable to
   be covered by the GNU General Public License. This exception does
   not however invalidate any other reasons why the executable file
   might be covered by the GNU General Public License.
-------------------------------------------------------------------------*/

 /*
  * Header file to overcome 8051 compiler differences for specifying special
  * function registers, memory spaces and interrupt handlers. This project
  * supports SDCC, Keil C51 and a syntax-only CLion code-insight mode. The
  * compilers are identified by their predefined macros. See also:
  * http://predef.sourceforge.net/precomp.html
  *
  * SBIT and SFR define special bit and special function registers at the given
  * address. SFR16 and SFR32 define sfr combinations at adjacent addresses in
  * little-endian format. SFR16E and SFR32E define sfr combinations without
  * prerequisite byte order or adjacency. None of these multi-byte sfr
  * combinations will guarantee the order in which they are accessed when read
  * or written.
  * SFR16X and SFR32X for 16 bit and 32 bit xdata registers are not defined
  * to avoid portability issues because of compiler endianness.
  * SFR16LEX is provided for 16 bit little endian xdata registers. It is usable
  * on little endian compilers only; on big endian compilers, these registers
  * will not be defined.
  * This file is to be included in every microcontroller specific header file.
  * Example:
  *
  * // my_mcu.h: sfr definitions for my mcu
  * #include <compiler.h>
  *
  * SBIT  (P0_1, 0x80, 1);      // Port 0 pin 1
  *
  * SFR   (P0, 0x80);           // Port 0
  *
  * SFRX  (CPUCS, 0xE600);      // Cypress FX2 Control and Status register in xdata memory at 0xE600
  *
  * SFR16 (TMR2, 0xCC);         // Timer 2, lsb at 0xCC, msb at 0xCD
  *
  * SFR16E(TMR0, 0x8C8A);       // Timer 0, lsb at 0x8A, msb at 0x8C
  *
  * SFR32 (MAC0ACC, 0x93);      // SiLabs C8051F120 32 bits MAC0 Accumulator, lsb at 0x93, msb at 0x96
  *
  * SFR32E(SUMR, 0xE5E4E3E2);   // TI MSC1210 SUMR 32 bits Summation register, lsb at 0xE2, msb at 0xE5
  *
 */

#ifndef COMPILER_H
#define COMPILER_H

#if defined(__SDCC_SYNTAX_FIX)
# include <stdbool.h>
# define SBIT(name, addr, bit)  volatile bool           name
# define SFR(name, addr)        volatile unsigned char  name
# define SFRX(name, addr)       volatile unsigned char  name
# define SFR16(name, addr)      volatile unsigned short name
# define SFR16E(name, fulladdr) volatile unsigned short name
# define SFR16LEX(name, addr)   volatile unsigned short name
# define SFR32(name, addr)      volatile unsigned long  name
# define SFR32E(name, fulladdr) volatile unsigned long  name
# define INTERRUPT(name, vector) void name(void)
# define INTERRUPT_USING(name, vector, bank) void name(void)
# define NOP() ((void)0)
# define DATA
# define IDATA
# define PDATA
# define XDATA
# define CODE
# define REENTRANT

/** SDCC - Small Device C Compiler */
#elif defined(SDCC) || defined(__SDCC)
# define SBIT(name, addr, bit)  __sbit  __at(addr+bit)                    name
# define SFR(name, addr)        __sfr   __at(addr)                        name
# define SFRX(name, addr)       __xdata volatile unsigned char __at(addr) name
# define SFR16(name, addr)      __sfr16 __at(((addr+1U)<<8) | addr)       name
# define SFR16E(name, fulladdr) __sfr16 __at(fulladdr)                    name
# define SFR16LEX(name, addr)   __xdata volatile unsigned short __at(addr) name
# define SFR32(name, addr)      __sfr32 __at(((addr+3UL)<<24) | ((addr+2UL)<<16) | ((addr+1UL)<<8) | addr) name
# define SFR32E(name, fulladdr) __sfr32 __at(fulladdr)                    name

# define INTERRUPT(name, vector) void name(void) __interrupt(vector)
# define INTERRUPT_USING(name, vector, bank) void name(void) __interrupt(vector) __using(bank)
# define NOP() __asm NOP __endasm
# define DATA __data
# define IDATA __idata
# define PDATA __pdata
# define XDATA __xdata
# define CODE __code
# define REENTRANT __reentrant

/** Keil C51 */
#elif defined(__CX51__) || defined(__C51__)
# define SBIT(name, addr, bit)  sbit  name = addr^bit
# define SFR(name, addr)        sfr   name = addr
# define SFRX(name, addr)       volatile unsigned char xdata name _at_ addr
# define SFR16(name, addr)      sfr16 name = addr
# define SFR16E(name, fulladdr) /* not supported by Keil C51 */
# define SFR16LEX(name, addr)   /* not supported by Keil C51 */
# define SFR32(name, addr)      /* not supported by Keil C51 */
# define SFR32E(name, fulladdr) /* not supported by Keil C51 */
# define INTERRUPT(name, vector) void name(void) interrupt vector
# define INTERRUPT_USING(name, vector, bank) void name(void) interrupt vector using bank
extern void _nop_(void);
# define NOP() _nop_()
# define DATA data
# define IDATA idata
# define PDATA pdata
# define XDATA xdata
# define CODE code
# define REENTRANT reentrant

#else
# error "Unsupported 8051 compiler"

#endif

#endif /* COMPILER_H */
