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
