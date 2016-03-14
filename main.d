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


string file_name = null;

public class Screen {
	static immutable int x = 240;
	static immutable int y = 160;
	static immutable int width = 240;
	static immutable int height = 160;
}

class CPU {
	static immutable string make = "";
	static immutable string model = "";
	static immutable u8 bits = 8;
	static immutable u32 clock_speed = 1_678_000;

	bool _is_running = false;

	public this() {
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
	auto f = std.stdio.File(file_name, "r");
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
	file_name = args[1];

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
