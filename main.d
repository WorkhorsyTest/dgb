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
	u8[0xFFFF] _memory;
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
		// http://imrannazar.com/Gameboy-Z80-Opcode-Map

	}

// 0
	void operation_nop() {}
	void operation_ld_bc_nn() {}
	void operation_ld_addr_bc_a() {}
	void operation_inc_bc() {}
	void operation_inc_b() {}
	void operation_dec_b() {}
	void operation_ld_b_n() {}
	void operation_rlc_a() {}
	void operation_ld_addr_nn_sp() {}
	void operation_add_hl_bc() {}
	void operation_ld_a_addr_bc() {}
	void operation_dec_bc() {}
	void operation_inc_c() {}
	void operation_dec_c() {}
	void operation_ld_c_n() {}
	void operation_rrc_a() {}
	// 1
	void operation_stop() {}
	void operation_ld_de_nn() {}
	void operation_ld_addr_de_a() {}
	void operation_inc_de() {}
	void operation_inc_d() {}
	void operation_dec_d() {}
	void operation_ld_d_n() {}
	void operation_rl_a() {}
	void operation_jr_n() {}
	void operation_add_hl_de() {}
	void operation_ld_a_addr_de() {}
	void operation_dec_de() {}
	void operation_inc_e() {}
	void operation_dec_e() {}
	void operation_ld_e_n() {}
	void operation_rr_a() {}
		// 2
	void operation_jr_nz_n() {}
	void operation_ld_hl_nn() {}
	void operation_ldi_addr_hl_a() {}
	void operation_inc_hl() {}
	void operation_inc_h() {}
	void operation_dec_h() {}
	void operation_ld_h_n() {}
	void operation_daa() {}
	void operation_jr_z_n() {}
	void operation_add_hl_hl() {}
	void operation_ldi_a_addr_hl() {}
	void operation_dec_hl() {}
	void operation_inc_l() {}
	void operation_dec_l() {}
	void operation_ld_l_n() {}
	void operation_cpl() {}
		// 3
	void operation_jr_nc_n() {}
	void operation_ld_sp_nn() {}
	void operation_ldd_addr_hl_a() {}
	void operation_inc_sp() {}
	void operation_inc_addr_hl() {}
	void operation_dec_addr_hl() {}
	void operation_ld_addr_hl_n() {}
	void operation_scf() {}
	void operation_jr_c_n() {}
	void operation_add_hl_sp() {}
	void operation_ldd_a_addr_hl() {}
	void operation_dec_sp() {}
	void operation_inc_a() {}
	void operation_dec_a() {}
	void operation_ld_a_n() {}
	void operation_ccf() {}
	// 4
	void operation_ld_b_b() {}
	void operation_ld_b_c() {}
	void operation_ld_b_d() {}
	void operation_ld_b_e() {}
	void operation_ld_b_h() {}
	void operation_ld_b_l() {}
	void operation_ld_b_addr_hl() {}
	void operation_ld_b_a() {}
	void operation_ld_c_b() {}
	void operation_ld_c_c() {}
	void operation_ld_c_d() {}
	void operation_ld_c_e() {}
	void operation_ld_c_h() {}
	void operation_ld_c_l() {}
	void operation_ld_c_addr_hl() {}
	void operation_ld_c_a() {}
		// 5
	void operation_ld_d_b() {}
	void operation_ld_d_c() {}
	void operation_ld_d_d() {}
	void operation_ld_d_e() {}
	void operation_ld_d_h() {}
	void operation_ld_d_l() {}
	void operation_ld_d_addr_hl() {}
	void operation_ld_d_a() {}
	void operation_ld_e_b() {}
	void operation_ld_e_c() {}
	void operation_ld_e_d() {}
	void operation_ld_e_e() {}
	void operation_ld_e_l() {}
	void operation_ld_e_h() {}
	void operation_ld_e_addr_hl() {}
	void operation_ld_e_a() {}
	// 6
	void operation_ld_h_b() {}
	void operation_ld_h_c() {}
	void operation_ld_h_d() {}
	void operation_ld_h_e() {}
	void operation_ld_h_h() {}
	void operation_ld_h_l() {}
	void operation_ld_h_addr_hl() {}
	void operation_ld_h_a() {}
	void operation_ld_l_b() {}
	void operation_ld_l_c() {}
	void operation_ld_l_d() {}
	void operation_ld_l_e() {}
	void operation_ld_l_h() {}
	void operation_ld_l_l() {}
	void operation_ld_l_addr_hl() {}
	void operation_ld_l_a() {}
		// 7
	void operation_ld_addr_hl_b() {}
	void operation_ld_addr_hl_c() {}
	void operation_ld_addr_hl_d() {}
	void operation_ld_addr_hl_e() {}
	void operation_ld_addr_hl_h() {}
	void operation_ld_addr_hl_l() {}
	void operation_halt() {}
	void operation_ld_addr_hl_a() {}
	void operation_ld_a_b() {}
	void operation_ld_a_c() {}
	void operation_ld_a_d() {}
	void operation_ld_a_e() {}
	void operation_ld_a_h() {}
	void operation_ld_a_l() {}
	void operation_ld_a_addr_hl() {}
	void operation_ld_a_a() {}
		// 8
	void operation_add_a_b() {}
	void operation_add_a_c() {}
	void operation_add_a_d() {}
	void operation_add_a_e() {}
	void operation_add_a_h() {}
	void operation_add_a_l() {}
	void operation_add_a_addr_hl() {}
	void operation_add_a_a() {}
	void operation_adc_a_b() {}
	void operation_adc_a_c() {}
	void operation_adc_a_d() {}
	void operation_adc_a_e() {}
	void operation_adc_a_h() {}
	void operation_adc_a_l() {}
	void operation_adc_a_addr_hl() {}
	void operation_adc_a_a() {}
	// 9
	void operation_sub_a_b() {}
	void operation_sub_a_c() {}
	void operation_sub_a_d() {}
	void operation_sub_a_e() {}
	void operation_sub_a_h() {}
	void operation_sub_a_l() {}
	void operation_sub_a_addr_hl() {}
	void operation_sub_a_a() {}
	void operation_sbc_a_b() {}
	void operation_sbc_a_c() {}
	void operation_sbc_a_d() {}
	void operation_sbc_a_e() {}
	void operation_sbc_a_h() {}
	void operation_sbc_a_l() {}
	void operation_sbc_a_addr_hl() {}
	void operation_sbc_a_a() {}
		// A
	void operation_and_b() {}
	void operation_and_c() {}
	void operation_and_d() {}
	void operation_and_e() {}
	void operation_and_h() {}
	void operation_and_l() {}
	void operation_and_addr_hl() {}
	void operation_and_a() {}
	void operation_xor_b() {}
	void operation_xor_c() {}
	void operation_xor_d() {}
	void operation_xor_e() {}
	void operation_xor_h() {}
	void operation_xor_l() {}
	void operation_xor_addr_hl() {}
	void operation_xor_a() {}
	// B
	void operation_or_b() {}
	void operation_or_c() {}
	void operation_or_d() {}
	void operation_or_e() {}
	void operation_or_h() {}
	void operation_or_l() {}
	void operation_or_addr_hl() {}
	void operation_or_a() {}
	void operation_cp_b() {}
	void operation_cp_c() {}
	void operation_cp_d() {}
	void operation_cp_e() {}
	void operation_cp_h() {}
	void operation_cp_l() {}
	void operation_cp_addr_hl() {}
	void operation_cp_a() {}
	// C
	void operation_ret_nz() {}
	void operation_pop_bc() {}
	void operation_jp_nz_nn() {}
	void operation_jp_nn() {}
	void operation_call_nz_nn() {}
	void operation_push_bc() {}
	void operation_add_a_n() {}
	void operation_rst_0() {}
	void operation_ret_z() {}
	void operation_ret() {}
	void operation_jp_z_nn() {}
	void operation_ext_ops() {}
	void operation_call_z_nn() {}
	void operation_call_nn() {}
	void operation_adc_a_n() {}
	void operation_rst_8() {}
	// D
	void operation_ret_nc() {}
	void operation_pop_de() {}
	void operation_jp_nc_nn() {}
	void operation_xx() {}
	void operation_call_nc_nn() {}
	void operation_push_de() {}
	void operation_sub_a_n() {}
	void operation_rst_10() {}
	void operation_ret_c() {}
	void operation_reti() {}
	void operation_jp_c_nn() {}
	void operation_xx() {}
	void operation_call_c_nn() {}
	void operation_xx() {}
	void operation_sbc_a_n() {}
	void operation_rst_18() {}
	// E
	void operation_ldh_addr_n_a() {}
	void operation_pop_hl() {}
	void operation_ldh_addr_c_a() {}
	void operation_xx() {}
	void operation_xx() {}
	void operation_push_hl() {}
	void operation_and_n() {}
	void operation_rst_20() {}
	void operation_add_sp_d() {}
	void operation_jp_addr_hl() {}
	void operation_ld_addr_nn_a() {}
	void operation_xx() {}
	void operation_xx() {}
	void operation_xx() {}
	void operation_xor_n() {}
	void operation_rst_28() {}
		// F
	void operation_ldh_a_addr_n() {}
	void operation_pop_af() {}
	void operation_xx() {}
	void operation_di() {}
	void operation_xx() {}
	void operation_push_af() {}
	void operation_or_n() {}
	void operation_rst_30() {}
	void operation_ldhl_sp_d() {}
	void operation_ld_sp_hl() {}
	void operation_ld_a_addr_nn() {}
	void operation_ei() {}
	void operation_xx() {}
	void operation_xx() {}
	void operation_cp_n() {}
	void operation_rst_38() {}





		// 0
	void operation_rlc_b() {}
	void operation_rlc_c() {}
	void operation_rlc_d() {}
	void operation_rlc_e() {}
	void operation_rlc_h() {}
	void operation_rlc_l() {}
	void operation_rlc_hl() {}
	void operation_rlc_a() {}
	void operation_rrc_b() {}
	void operation_rrc_c() {}
	void operation_rrc_d() {}
	void operation_rrc_e() {}
	void operation_rrc_h() {}
	void operation_rrc_l() {}
	void operation_rrc_hl() {}
	void operation_rrc_a() {}
		// 1
	void operation_rl_b() {}
	void operation_rl_c() {}
	void operation_rl_d() {}
	void operation_rl_e() {}
	void operation_rl_h() {}
	void operation_rl_l() {}
	void operation_rl_hl() {}
	void operation_rl_a() {}
	void operation_rr_b() {}
	void operation_rr_c() {}
	void operation_rr_d() {}
	void operation_rr_e() {}
	void operation_rr_h() {}
	void operation_rr_l() {}
	void operation_rr_hl() {}
	void operation_rr_a() {}
		// 2
	void operation_sla_b() {}
	void operation_sla_c() {}
	void operation_sla_d() {}
	void operation_sla_e() {}
	void operation_sla_h() {}
	void operation_sla_l() {}
	void operation_sla_hl() {}
	void operation_sla_a() {}
	void operation_sra_b() {}
	void operation_sra_c() {}
	void operation_sra_d() {}
	void operation_sra_e() {}
	void operation_sra_h() {}
	void operation_sra_l() {}
	void operation_sra_hl() {}
	void operation_sra_a() {}
		// 3
	void operation_swap_b() {}
	void operation_swap_c() {}
	void operation_swap_d() {}
	void operation_swap_e() {}
	void operation_swap_h() {}
	void operation_swap_l() {}
	void operation_swap_hl() {}
	void operation_swap_a() {}
	void operation_srl_b() {}
	void operation_srl_c() {}
	void operation_srl_d() {}
	void operation_srl_e() {}
	void operation_srl_h() {}
	void operation_srl_l() {}
	void operation_srl_hl() {}
	void operation_srl_a() {}
		// 4
	void operation_bit_0_b() {}
	void operation_bit_0_c() {}
	void operation_bit_0_d() {}
	void operation_bit_0_e() {}
	void operation_bit_0_h() {}
	void operation_bit_0_l() {}
	void operation_bit_0_hl() {}
	void operation_bit_0_a() {}
	void operation_bit_1_b() {}
	void operation_bit_1_c() {}
	void operation_bit_1_d() {}
	void operation_bit_1_e() {}
	void operation_bit_1_h() {}
	void operation_bit_1_l() {}
	void operation_bit_1_hl() {}
	void operation_bit_1_a() {}
		// 5
	void operation_bit_2_b() {}
	void operation_bit_2_c() {}
	void operation_bit_2_d() {}
	void operation_bit_2_e() {}
	void operation_bit_2_h() {}
	void operation_bit_2_l() {}
	void operation_bit_2_hl() {}
	void operation_bit_2_a() {}
	void operation_bit_3_b() {}
	void operation_bit_3_c() {}
	void operation_bit_3_d() {}
	void operation_bit_3_e() {}
	void operation_bit_3_h() {}
	void operation_bit_3_l() {}
	void operation_bit_3_hl() {}
	void operation_bit_3_a() {}
		// 6
	void operation_bit_4_b() {}
	void operation_bit_4_c() {}
	void operation_bit_4_d() {}
	void operation_bit_4_e() {}
	void operation_bit_4_h() {}
	void operation_bit_4_l() {}
	void operation_bit_4_hl() {}
	void operation_bit_4_a() {}
	void operation_bit_5_b() {}
	void operation_bit_5_c() {}
	void operation_bit_5_d() {}
	void operation_bit_5_e() {}
	void operation_bit_5_h() {}
	void operation_bit_5_l() {}
	void operation_bit_5_hl() {}
	void operation_bit_5_a() {}
		// 7
	void operation_bit_6_b() {}
	void operation_bit_6_c() {}
	void operation_bit_6_d() {}
	void operation_bit_6_e() {}
	void operation_bit_6_h() {}
	void operation_bit_6_l() {}
	void operation_bit_6_hl() {}
	void operation_bit_6_a() {}
	void operation_bit_7_b() {}
	void operation_bit_7_c() {}
	void operation_bit_7_d() {}
	void operation_bit_7_e() {}
	void operation_bit_7_h() {}
	void operation_bit_7_l() {}
	void operation_bit_7_hl() {}
	void operation_bit_7_a() {}
		// 8
	void operation_res_0_b() {}
	void operation_res_0_c() {}
	void operation_res_0_d() {}
	void operation_res_0_e() {}
	void operation_res_0_h() {}
	void operation_res_0_l() {}
	void operation_res_0_hl() {}
	void operation_res_0_a() {}
	void operation_res_1_b() {}
	void operation_res_1_c() {}
	void operation_res_1_d() {}
	void operation_res_1_e() {}
	void operation_res_1_h() {}
	void operation_res_1_l() {}
	void operation_res_1_hl() {}
	void operation_res_1_a() {}
		// 9
	void operation_res_2_b() {}
	void operation_res_2_c() {}
	void operation_res_2_d() {}
	void operation_res_2_e() {}
	void operation_res_2_h() {}
	void operation_res_2_l() {}
	void operation_res_2_hl() {}
	void operation_res_2_a() {}
	void operation_res_3_b() {}
	void operation_res_3_c() {}
	void operation_res_3_d() {}
	void operation_res_3_e() {}
	void operation_res_3_h() {}
	void operation_res_3_l() {}
	void operation_res_3_hl() {}
	void operation_res_3_a() {}
		// a
	void operation_res_4_b() {}
	void operation_res_4_c() {}
	void operation_res_4_d() {}
	void operation_res_4_e() {}
	void operation_res_4_h() {}
	void operation_res_4_l() {}
	void operation_res_4_hl() {}
	void operation_res_4_a() {}
	void operation_res_5_b() {}
	void operation_res_5_c() {}
	void operation_res_5_d() {}
	void operation_res_5_e() {}
	void operation_res_5_h() {}
	void operation_res_5_l() {}
	void operation_res_5_hl() {}
	void operation_res_5_a() {}
		// b
	void operation_res_6_b() {}
	void operation_res_6_c() {}
	void operation_res_6_d() {}
	void operation_res_6_e() {}
	void operation_res_6_h() {}
	void operation_res_6_l() {}
	void operation_res_6_hl() {}
	void operation_res_6_a() {}
	void operation_res_7_b() {}
	void operation_res_7_c() {}
	void operation_res_7_d() {}
	void operation_res_7_e() {}
	void operation_res_7_h() {}
	void operation_res_7_l() {}
	void operation_res_7_hl() {}
	void operation_res_7_a() {}
		// c
	void operation_set_0_b() {}
	void operation_set_0_c() {}
	void operation_set_0_d() {}
	void operation_set_0_e() {}
	void operation_set_0_h() {}
	void operation_set_0_l() {}
	void operation_set_0_hl() {}
	void operation_set_0_a() {}
	void operation_set_1_b() {}
	void operation_set_1_c() {}
	void operation_set_1_d() {}
	void operation_set_1_e() {}
	void operation_set_1_h() {}
	void operation_set_1_l() {}
	void operation_set_1_hl() {}
	void operation_set_1_a() {}
// d
	void operation_set_2_b() {}
	void operation_set_2_c() {}
	void operation_set_2_d() {}
	void operation_set_2_e() {}
	void operation_set_2_h() {}
	void operation_set_2_l() {}
	void operation_set_2_hl() {}
	void operation_set_2_a() {}
	void operation_set_3_b() {}
	void operation_set_3_c() {}
	void operation_set_3_d() {}
	void operation_set_3_e() {}
	void operation_set_3_h() {}
	void operation_set_3_l() {}
	void operation_set_3_hl() {}
	void operation_set_3_a() {}
		// e
	void operation_set_4_b() {}
	void operation_set_4_c() {}
	void operation_set_4_d() {}
	void operation_set_4_e() {}
	void operation_set_4_h() {}
	void operation_set_4_l() {}
	void operation_set_4_hl() {}
	void operation_set_4_a() {}
	void operation_set_5_b() {}
	void operation_set_5_c() {}
	void operation_set_5_d() {}
	void operation_set_5_e() {}
	void operation_set_5_h() {}
	void operation_set_5_l() {}
	void operation_set_5_hl() {}
	void operation_set_5_a() {}
	// F
	void operation_set_6_b() {}
	void operation_set_6_c() {}
	void operation_set_6_d() {}
	void operation_set_6_e() {}
	void operation_set_6_h() {}
	void operation_set_6_l() {}
	void operation_set_6_hl() {}
	void operation_set_6_a() {}
	void operation_set_7_b() {}
	void operation_set_7_c() {}
	void operation_set_7_d() {}
	void operation_set_7_e() {}
	void operation_set_7_h() {}
	void operation_set_7_l() {}
	void operation_set_7_hl() {}
	void operation_set_7_a() {}
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
