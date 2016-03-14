/*
* DGB: a GameBoy emulator
* DGB is licensed under the AGPL v3
* Copyright (c) 2016, Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
*/

import std.stdio;
import std.conv;
import core.thread;
import std.string;
import sdl;
import types;


string g_file_name = null;

public class Screen {
	static immutable int x = 160;
	static immutable int y = 144;
	static immutable int width = 160;
	static immutable int height = 144;
}

// https://en.wikipedia.org/wiki/Game_Boy
// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 2.3. Game Boy Specs
class CPU {
	static immutable string make = "Sharp";
	static immutable string model = "LR35902";
	static immutable u8 bits = 8;
	static immutable u32 clock_speed = 4_194_304;

	bool _is_running = false;
	u8 _a;
	u8 _b;
	u8 _c;
	u8 _d;
	u8 _e;
	u8 _f;
	u8 _h;
	u8 _l;
	u16 _sp;
	u16 _pc;

	u16 _af() { return (_a << 8) | _f; }
	u16 _cb() { return (_c << 8) | _b; }
	u16 _de() { return (_d << 8) | _e; }
	u16 _hl() { return (_h << 8) | _l; }

	bool is_flag_zero() {
		return (_f & (1 << 7)) > 0;
	}

	bool is_flag_subtract() {
		return (_f & (1 << 6)) > 0;
	}

	bool is_flag_half_carry() {
		return (_f & (1 << 5)) > 0;
	}

	bool is_flag_carry() {
		return (_f & (1 << 4)) > 0;
	}

	public this() {
		// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.2.3. Program Counter
		_pc = 0x100;
		// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.2.4. Stack Pointer
		_sp = 0xFFFE;
		_is_running = true;
	}

	void reset() {
	}

	void run_next_operation() {
		u8 opcode = _memory[_pc++];

		// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.3. Commands
		switch (opcode) {
			// LD nn, n
			case 0x06: break;
			case 0x0E: break;
			case 0x16: break;
			case 0x1E: break;
			case 0x26: break;
			case 0x2E: break;
			// LD r1, r2
			case 0x7F: break;
			case 0x78: break;
			case 0x79: break;
			case 0x7A: break;
			case 0x7B: break;
			case 0x7C: break;
			case 0x7D: break;
			case 0x7E: break;
			case 0x40: break;
			case 0x41: break;
			case 0x42: break;
			case 0x43: break;
			case 0x44: break;
			case 0x45: break;
			case 0x46: break;
			case 0x48: break;
			case 0x49: break;
			case 0x4A: break;
			case 0x4B: break;
			case 0x4C: break;
			case 0x4D: break;
			case 0x4E: break;
			case 0x50: break;
			case 0x51: break;
			case 0x52: break;
			case 0x53: break;
			case 0x54: break;
			case 0x55: break;
			case 0x56: break;
			case 0x58: break;
			case 0x59: break;
			case 0x5A: break;
			case 0x5B: break;
			case 0x5C: break;
			case 0x5D: break;
			case 0x5E: break;
			case 0x60: break;
			case 0x61: break;
			case 0x62: break;
			case 0x63: break;
			case 0x64: break;
			case 0x65: break;
			case 0x66: break;
			case 0x68: break;
			case 0x69: break;
			case 0x6A: break;
			case 0x6B: break;
			case 0x6C: break;
			case 0x6D: break;
			case 0x6E: break;
			case 0x70: break;
			case 0x71: break;
			case 0x72: break;
			case 0x73: break;
			case 0x74: break;
			case 0x75: break;
			case 0x36: break;
			// LD A, n
			case 0x7F: break;
			case 0x78: break;
			case 0x79: break;
			case 0x7A: break;
			case 0x7B: break;
			case 0x7C: break;
			case 0x7D: break;
			case 0x0A: break;
			case 0x1A: break;
			case 0x7E: break;
			case 0xFA: break;
			case 0x3F: break;
			// LD n, A
			case 0x7F: break;
			case 0x47: break;
			case 0x4F: break;
			case 0x57: break;
			case 0x5F: break;
			case 0x67: break;
			case 0x6F: break;
			case 0x02: break;
			case 0x12: break;
			case 0x77: break;
			case 0xEA: break;
			// LD A, (C)
			case 0xF2: break;
			// LD (C), A
			case 0xE2: break;
			// LDD A, (HL)
			case 0x3A: break;
			// LDD (HL), A
			case 0x32: break;
			// LDI A, (HL)
			case 0x2A: break;
			// LDI (HL), A
			case 0x22: break;
			// LDH (n), A
			case 0xE0: break;
			// LDH A, (n)
			case 0xF0: break;
			// LD n, nn
			case 0x01: break;
			case 0x11: break;
			case 0x21: break;
			case 0x31: break;
			// LD SP, HL
			case 0xF9: break;
			// LDHL SP, n
			case 0xF8: break;
			// LD (nn), SP
			case 0x08: break;
			// PUSH nn
			case 0xF5: break;
			case 0xC5: break;
			case 0xD5: break;
			case 0xE5: break;
			// POP nn
			case 0xF1: break;
			case 0xC1: break;
			case 0xD1: break;
			case 0xE1: break;
			// ADD A, n
			case 0x87: break;
			case 0x80: break;
			case 0x81: break;
			case 0x82: break;
			case 0x83: break;
			case 0x84: break;
			case 0x85: break;
			case 0x86: break;
			case 0xC6: break;
			// ADC A, n
			case 0x8F: break;
			case 0x88: break;
			case 0x89: break;
			case 0x8A: break;
			case 0x8B: break;
			case 0x8C: break;
			case 0x8D: break;
			case 0x8E: break;
			case 0xCE: break;
			// SUB n
			case 0x97: break;
			case 0x90: break;
			case 0x91: break;
			case 0x92: break;
			case 0x93: break;
			case 0x94: break;
			case 0x95: break;
			case 0x96: break;
			case 0xD6: break;
			// SBC A, n
			case 0x9F: break;
			case 0x98: break;
			case 0x99: break;
			case 0x9A: break;
			case 0x9B: break;
			case 0x9C: break;
			case 0x9D: break;
			case 0x9E: break;
			//case ??: break; // SBC A, #
			// AND n
			case 0xA7: break;
			case 0xA0: break;
			case 0xA1: break;
			case 0xA2: break;
			case 0xA3: break;
			case 0xA4: break;
			case 0xA5: break;
			case 0xA6: break;
			case 0xE6: break;
			// OR n
			case 0xB7: break;
			case 0xB0: break;
			case 0xB1: break;
			case 0xB2: break;
			case 0xB3: break;
			case 0xB4: break;
			case 0xB5: break;
			case 0xB6: break;
			case 0xF6: break;
			// XOR n
			case 0xAF: break;
			case 0xA8: break;
			case 0xA9: break;
			case 0xAA: break;
			case 0xAB: break;
			case 0xAC: break;
			case 0xAD: break;
			case 0xAE: break;
			case 0xEE: break;
			// CP n
			case 0xBF: break;
			case 0xB8: break;
			case 0xB9: break;
			case 0xBA: break;
			case 0xBB: break;
			case 0xBC: break;
			case 0xBD: break;
			case 0xBE: break;
			case 0xFE: break;
			// INC n
			case 0x3C: break;
			case 0x04: break;
			case 0x0C: break;
			case 0x14: break;
			case 0x1C: break;
			case 0x24: break;
			case 0x2C: break;
			case 0x34: break;
			// DEC n
			case 0x3D: break;
			case 0x05: break;
			case 0x0D: break;
			case 0x15: break;
			case 0x1D: break;
			case 0x25: break;
			case 0x2D: break;
			case 0x35: break;
			// ADD HL, n
			case 0x09: break;
			case 0x19: break;
			case 0x29: break;
			case 0x39: break;
			// ADD SP, n
			case 0xE8: break;
			// INC nn
			case 0x03: break;
			case 0x13: break;
			case 0x23: break;
			case 0x33: break;
			// DEC nn
			case 0x0B: break;
			case 0x1B: break;
			case 0x2B: break;
			case 0x3B: break;
			// SWAP n
			case 0x37: break;
			case 0x30: break;
			case 0x31: break;
			case 0x32: break;
			case 0x33: break;
			case 0x34: break;
			case 0x35: break;
			case 0x36: break;
			// DAA
			case 0x27: break;
			// CPL
			case 0x2F: break;
			// CCF
			case 0x3F: break;
			// SCF
			case 0x37: break;
			// NOP
			case 0x00: break;
			// HALT
			case 0x76: break;
			// STOP
			case 0x10: break;
			// DI
			case 0xF3: break;
			// EI
			case 0xFB: break;
			// RLCA
			case 0x07: break;
			// RLA
			case 0x17: break;
			// RRCA
			case 0x0F: break;
			// RRA
			case 0x1F: break;
			// RLC n
			case 0x07: break;
			case 0x00: break;
			case 0x01: break;
			case 0x02: break;
			case 0x03: break;
			case 0x04: break;
			case 0x05: break;
			case 0x06: break;
			// RL n
			case 0x17: break;
			case 0x10: break;
			case 0x11: break;
			case 0x12: break;
			case 0x13: break;
			case 0x14: break;
			case 0x15: break;
			case 0x16: break;
			// RRC n
			case 0x0F: break;
			case 0x08: break;
			case 0x09: break;
			case 0x0A: break;
			case 0x0B: break;
			case 0x0C: break;
			case 0x0D: break;
			case 0x0E: break;
			// RR n
			case 0x1F: break;
			case 0x18: break;
			case 0x19: break;
			case 0x1A: break;
			case 0x1B: break;
			case 0x1C: break;
			case 0x1D: break;
			case 0x1E: break;
			// SLA n
			case 0x27: break;
			case 0x20: break;
			case 0x21: break;
			case 0x22: break;
			case 0x23: break;
			case 0x24: break;
			case 0x25: break;
			case 0x26: break;
			// SRA n
			case 0x2F: break;
			case 0x28: break;
			case 0x29: break;
			case 0x2A: break;
			case 0x2B: break;
			case 0x2B: break;
			case 0x2D: break;
			case 0x2E: break;
			// SRL n
			case 0x3F: break;
			case 0x38: break;
			case 0x39: break;
			case 0x3A: break;
			case 0x3B: break;
			case 0x3C: break;
			case 0x3D: break;
			case 0x3E: break;
			// BIT b, r
			case 0x47: break;
			case 0x40: break;
			case 0x41: break;
			case 0x42: break;
			case 0x43: break;
			case 0x44: break;
			case 0x45: break;
			case 0x46: break;
			// SET b, r
			case 0xC7: break;
			case 0xC0: break;
			case 0xC1: break;
			case 0xC2: break;
			case 0xC3: break;
			case 0xC4: break;
			case 0xC5: break;
			case 0xC6: break;
			// RES b, r
			case 0x87: break;
			case 0x80: break;
			case 0x81: break;
			case 0x82: break;
			case 0x83: break;
			case 0x84: break;
			case 0x85: break;
			case 0x86: break;
			// JP nn
			case 0xC3: break;
			// JP cc, nn
			case 0xC2: break;
			case 0xCA: break;
			case 0xD2: break;
			case 0xDA: break;
			// JP (HL)
			case 0xE9: break;
			// JR n
			case 0x18: break;
			// JR cc, n
			case 0x20: break;
			case 0x28: break;
			case 0x30: break;
			case 0x38: break;
			// CALL nn
			case 0xCD: break;
			// CALL cc, nn
			case 0xC4: break;
			case 0xCC: break;
			case 0xD4: break;
			case 0xDC: break;
			// RST n
			case 0xC7: break;
			case 0xCF: break;
			case 0xD7: break;
			case 0xDF: break;
			case 0xE7: break;
			case 0xEF: break;
			case 0xF7: break;
			case 0xFF: break;
			// RET
			case 0xC9: break;
			// RET cc
			case 0xC0: break;
			case 0xC8: break;
			case 0xD0: break;
			case 0xD8: break;
			// RETI
			case 0xD9: break;
		}
	}
}

immutable u32 HEADER_SIZE = 16;

public void load_cart() {
	// Read the file into an array
	auto f = std.stdio.File(g_file_name, "r");
	char[HEADER_SIZE] header;
	f.rawRead(header);
	writefln("header size: %dB", header.length);

	f.close();
}

int main(string[] args) {
	// Make backtraces work in Linux
	version(linux) {
		import backtrace;
		PrintOptions options;
		options.detailedForN = 2;        //number of frames to show code for
		options.numberOfLinesBefore = 3; //number of lines of code to show before the specific line
		options.numberOfLinesAfter = 3;  //number of lines of code to show after the specific line
		options.colored = false;         //enable colored output for the backtrace
		options.stopAtDMain = true;      //show stack traces after the entry point of the D code
		backtrace.install(stderr, options);
	}

	// Make sure a file name was passed
	if (args.length < 2) {
		stderr.writeln("Usage: ./main example.gb");
		return -1;
	}
	g_file_name = args[1];

	// Initialize SDL, exit if there is an error
	if (SDL_Init(SDL_INIT_VIDEO) < 0) {
		stderr.writefln("Could not initialize SDL: %s", SDL_GetError());
		return -1;
	}

	// Grab a surface on the screen
	SDL_Surface* sdl_screen = SDL_SetVideoMode(Screen.width+Screen.x, Screen.height+Screen.y, 32, SDL_SWSURFACE|SDL_ANYFORMAT);
	if (!sdl_screen) {
		stderr.writefln("Couldn't create a surface: %s", SDL_GetError());
		return -1;
	}

	auto cpu = new CPU();
	cpu.reset();

	bool is_draw_time = false;
	while (cpu._is_running) {
		// Run the next operation
		try {
			cpu.run_next_operation();
		} catch(Exception err) {
			writefln("Unhandled Exception: %s", err);
			Thread.sleep(dur!("msecs")(5000));
			return -1;
		}

		// Each scanline
		if(is_draw_time) {
			// Check for quit events
			SDL_Event sdl_event;
			while(SDL_PollEvent(&sdl_event) == 1) {
				if(sdl_event.type == SDL_QUIT)
					cpu._is_running = false;
			}

			// Lock the screen if needed
			if(SDL_MUSTLOCK(sdl_screen)) {
				if(SDL_LockSurface(sdl_screen) < 0)
					return -1;
			}

			// Actually draw the screen


			// Unlock the screen if needed
			if(SDL_MUSTLOCK(sdl_screen)) {
				SDL_UnlockSurface(sdl_screen);
			}

			// Show the newly drawn screen
			SDL_Flip(sdl_screen);
			is_draw_time = false;
		}

		Thread.sleep(dur!("msecs")(100));
	}

	SDL_Quit();

	return 0;
}
