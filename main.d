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
	u16 _ticks;

	u16 _af() { return (_a << 8) | _f; }
	u16 _bc() { return (_b << 8) | _c; }
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

	void delegate()[] ops;
	void delegate()[] opcbs;

	public this() {
		// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.2.3. Program Counter
		_pc = 0x100;
		// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.2.4. Stack Pointer
		_sp = 0xFFFE;
		_is_running = true;

		opcbs = [
			// 1
			&opcb_rlc_b, &opcb_rlc_c, &opcb_rlc_d, &opcb_rlc_e,
			&opcb_rlc_h, &opcb_rlc_l, &opcb_rlc_hl, &opcb_rlc_a,
			&opcb_rrc_b, &opcb_rrc_c, &opcb_rrc_d, &opcb_rrc_e,
			&opcb_rrc_h, &opcb_rrc_l, &opcb_rrc_hl, &opcb_rrc_a,
				// 1
			&opcb_rl_b, &opcb_rl_c, &opcb_rl_d, &opcb_rl_e,
			&opcb_rl_h, &opcb_rl_l, &opcb_rl_hl, &opcb_rl_a,
			&opcb_rr_b, &opcb_rr_c, &opcb_rr_d, &opcb_rr_e,
			&opcb_rr_h, &opcb_rr_l, &opcb_rr_hl, &opcb_rr_a,
				// 2
			&opcb_sla_b, &opcb_sla_c, &opcb_sla_d, &opcb_sla_e,
			&opcb_sla_h, &opcb_sla_l, &opcb_sla_hl, &opcb_sla_a,
			&opcb_sra_b, &opcb_sra_c, &opcb_sra_d, &opcb_sra_e,
			&opcb_sra_h, &opcb_sra_l, &opcb_sra_hl, &opcb_sra_a,
				// 3
			&opcb_swap_b, &opcb_swap_c, &opcb_swap_d, &opcb_swap_e,
			&opcb_swap_h, &opcb_swap_l, &opcb_swap_hl, &opcb_swap_a,
			&opcb_srl_b, &opcb_srl_c, &opcb_srl_d, &opcb_srl_e,
			&opcb_srl_h, &opcb_srl_l, &opcb_srl_hl, &opcb_srl_a,
				// 4
			&opcb_bit_0_b,
			&opcb_bit_0_c,
			&opcb_bit_0_d,
			&opcb_bit_0_e,
			&opcb_bit_0_h,
			&opcb_bit_0_l,
			&opcb_bit_0_hl,
			&opcb_bit_0_a,
			&opcb_bit_1_b,
			&opcb_bit_1_c,
			&opcb_bit_1_d,
			&opcb_bit_1_e,
			&opcb_bit_1_h,
			&opcb_bit_1_l,
			&opcb_bit_1_hl,
			&opcb_bit_1_a,
				// 5
			&opcb_bit_2_b,
			&opcb_bit_2_c,
			&opcb_bit_2_d,
			&opcb_bit_2_e,
			&opcb_bit_2_h,
			&opcb_bit_2_l,
			&opcb_bit_2_hl,
			&opcb_bit_2_a,
			&opcb_bit_3_b,
			&opcb_bit_3_c,
			&opcb_bit_3_d,
			&opcb_bit_3_e,
			&opcb_bit_3_h,
			&opcb_bit_3_l,
			&opcb_bit_3_hl,
			&opcb_bit_3_a,
				// 6
			&opcb_bit_4_b,
			&opcb_bit_4_c,
			&opcb_bit_4_d,
			&opcb_bit_4_e,
			&opcb_bit_4_h,
			&opcb_bit_4_l,
			&opcb_bit_4_hl,
			&opcb_bit_4_a,
			&opcb_bit_5_b,
			&opcb_bit_5_c,
			&opcb_bit_5_d,
			&opcb_bit_5_e,
			&opcb_bit_5_h,
			&opcb_bit_5_l,
			&opcb_bit_5_hl,
			&opcb_bit_5_a,
				// 7
			&opcb_bit_6_b,
			&opcb_bit_6_c,
			&opcb_bit_6_d,
			&opcb_bit_6_e,
			&opcb_bit_6_h,
			&opcb_bit_6_l,
			&opcb_bit_6_hl,
			&opcb_bit_6_a,
			&opcb_bit_7_b,
			&opcb_bit_7_c,
			&opcb_bit_7_d,
			&opcb_bit_7_e,
			&opcb_bit_7_h,
			&opcb_bit_7_l,
			&opcb_bit_7_hl,
			&opcb_bit_7_a,
				// 8
			&opcb_res_0_b,
			&opcb_res_0_c,
			&opcb_res_0_d,
			&opcb_res_0_e,
			&opcb_res_0_h,
			&opcb_res_0_l,
			&opcb_res_0_hl,
			&opcb_res_0_a,
			&opcb_res_1_b,
			&opcb_res_1_c,
			&opcb_res_1_d,
			&opcb_res_1_e,
			&opcb_res_1_h,
			&opcb_res_1_l,
			&opcb_res_1_hl,
			&opcb_res_1_a,
				// 9
			&opcb_res_2_b,
			&opcb_res_2_c,
			&opcb_res_2_d,
			&opcb_res_2_e,
			&opcb_res_2_h,
			&opcb_res_2_l,
			&opcb_res_2_hl,
			&opcb_res_2_a,
			&opcb_res_3_b,
			&opcb_res_3_c,
			&opcb_res_3_d,
			&opcb_res_3_e,
			&opcb_res_3_h,
			&opcb_res_3_l,
			&opcb_res_3_hl,
			&opcb_res_3_a,
				// a
			&opcb_res_4_b,
			&opcb_res_4_c,
			&opcb_res_4_d,
			&opcb_res_4_e,
			&opcb_res_4_h,
			&opcb_res_4_l,
			&opcb_res_4_hl,
			&opcb_res_4_a,
			&opcb_res_5_b,
			&opcb_res_5_c,
			&opcb_res_5_d,
			&opcb_res_5_e,
			&opcb_res_5_h,
			&opcb_res_5_l,
			&opcb_res_5_hl,
			&opcb_res_5_a,
				// b
			&opcb_res_6_b,
			&opcb_res_6_c,
			&opcb_res_6_d,
			&opcb_res_6_e,
			&opcb_res_6_h,
			&opcb_res_6_l,
			&opcb_res_6_hl,
			&opcb_res_6_a,
			&opcb_res_7_b,
			&opcb_res_7_c,
			&opcb_res_7_d,
			&opcb_res_7_e,
			&opcb_res_7_h,
			&opcb_res_7_l,
			&opcb_res_7_hl,
			&opcb_res_7_a,
				// c
			&opcb_set_0_b,
			&opcb_set_0_c,
			&opcb_set_0_d,
			&opcb_set_0_e,
			&opcb_set_0_h,
			&opcb_set_0_l,
			&opcb_set_0_hl,
			&opcb_set_0_a,
			&opcb_set_1_b,
			&opcb_set_1_c,
			&opcb_set_1_d,
			&opcb_set_1_e,
			&opcb_set_1_h,
			&opcb_set_1_l,
			&opcb_set_1_hl,
			&opcb_set_1_a,
		// d
			&opcb_set_2_b,
			&opcb_set_2_c,
			&opcb_set_2_d,
			&opcb_set_2_e,
			&opcb_set_2_h,
			&opcb_set_2_l,
			&opcb_set_2_hl,
			&opcb_set_2_a,
			&opcb_set_3_b,
			&opcb_set_3_c,
			&opcb_set_3_d,
			&opcb_set_3_e,
			&opcb_set_3_h,
			&opcb_set_3_l,
			&opcb_set_3_hl,
			&opcb_set_3_a,
				// e
			&opcb_set_4_b,
			&opcb_set_4_c,
			&opcb_set_4_d,
			&opcb_set_4_e,
			&opcb_set_4_h,
			&opcb_set_4_l,
			&opcb_set_4_hl,
			&opcb_set_4_a,
			&opcb_set_5_b,
			&opcb_set_5_c,
			&opcb_set_5_d,
			&opcb_set_5_e,
			&opcb_set_5_h,
			&opcb_set_5_l,
			&opcb_set_5_hl,
			&opcb_set_5_a,
			// F
			&opcb_set_6_b,
			&opcb_set_6_c,
			&opcb_set_6_d,
			&opcb_set_6_e,
			&opcb_set_6_h,
			&opcb_set_6_l,
			&opcb_set_6_hl,
			&opcb_set_6_a,
			&opcb_set_7_b,
			&opcb_set_7_c,
			&opcb_set_7_d,
			&opcb_set_7_e,
			&opcb_set_7_h,
			&opcb_set_7_l,
			&opcb_set_7_hl,
			&opcb_set_7_a
		];

		ops = [
			// 0
			&op_nop, &op_ld_bc_nn, &op_ld_addr_bc_a, &op_inc_bc,
			&op_inc_b, &op_dec_b, &op_ld_b_n, &op_rlc_a,
			&op_ld_addr_nn_sp, &op_add_hl_bc, &op_ld_a_addr_bc,
			&op_dec_bc, &op_inc_c, &op_dec_c, &op_ld_c_n, &op_rrc_a,
			// 1
			&op_stop, &op_ld_de_nn, &op_ld_addr_de_a, &op_inc_de,
			&op_inc_d, &op_dec_d, &op_ld_d_n, &op_rl_a,
			&op_jr_n, &op_add_hl_de, &op_ld_a_addr_de, &op_dec_de,
			&op_inc_e, &op_dec_e, &op_ld_e_n, &op_rr_a,
			// 2
			&op_jr_nz_n, &op_ld_hl_nn, &op_ldi_addr_hl_a, &op_inc_hl,
			&op_inc_h, &op_dec_h, &op_ld_h_n, &op_daa,
			&op_jr_z_n, &op_add_hl_hl, &op_ldi_a_addr_hl, &op_dec_hl,
			&op_inc_l, &op_dec_l, &op_ld_l_n, &op_cpl,
			// 3
			&op_jr_nc_n, &op_ld_sp_nn, &op_ldd_addr_hl_a, &op_inc_sp,
			&op_inc_addr_hl, &op_dec_addr_hl, &op_ld_addr_hl_n, &op_scf,
			&op_jr_c_n, &op_add_hl_sp, &op_ldd_a_addr_hl, &op_dec_sp,
			&op_inc_a, &op_dec_a, &op_ld_a_n, &op_ccf,
			// 4
			&op_ld_b_b, &op_ld_b_c, &op_ld_b_d, &op_ld_b_e,
			&op_ld_b_h, &op_ld_b_l, &op_ld_b_addr_hl, &op_ld_b_a,
			&op_ld_c_b, &op_ld_c_c, &op_ld_c_d, &op_ld_c_e,
			&op_ld_c_h, &op_ld_c_l, &op_ld_c_addr_hl, &op_ld_c_a,
			// 5
			&op_ld_d_b, &op_ld_d_c, &op_ld_d_d, &op_ld_d_e,
			&op_ld_d_h, &op_ld_d_l, &op_ld_d_addr_hl, &op_ld_d_a,
			&op_ld_e_b, &op_ld_e_c, &op_ld_e_d, &op_ld_e_e,
			&op_ld_e_l, &op_ld_e_h, &op_ld_e_addr_hl, &op_ld_e_a,
			// 6
			&op_ld_h_b, &op_ld_h_c, &op_ld_h_d, &op_ld_h_e,
			&op_ld_h_h, &op_ld_h_l, &op_ld_h_addr_hl, &op_ld_h_a,
			&op_ld_l_b, &op_ld_l_c, &op_ld_l_d, &op_ld_l_e,
			&op_ld_l_h, &op_ld_l_l, &op_ld_l_addr_hl, &op_ld_l_a,
			// 7
			&op_ld_addr_hl_b, &op_ld_addr_hl_c, &op_ld_addr_hl_d, &op_ld_addr_hl_e,
			&op_ld_addr_hl_h, &op_ld_addr_hl_l, &op_halt, &op_ld_addr_hl_a,
			&op_ld_a_b, &op_ld_a_c, &op_ld_a_d, &op_ld_a_e,
			&op_ld_a_h, &op_ld_a_l, &op_ld_a_addr_hl, &op_ld_a_a,
			// 8
			&op_add_a_b, &op_add_a_c, &op_add_a_d, &op_add_a_e,
			&op_add_a_h, &op_add_a_l, &op_add_a_addr_hl, &op_add_a_a,
			&op_adc_a_b, &op_adc_a_c, &op_adc_a_d, &op_adc_a_e,
			&op_adc_a_h, &op_adc_a_l, &op_adc_a_addr_hl, &op_adc_a_a,
			// 9
			&op_sub_a_b, &op_sub_a_c, &op_sub_a_d, &op_sub_a_e,
			&op_sub_a_h, &op_sub_a_l, &op_sub_a_addr_hl, &op_sub_a_a,
			&op_sbc_a_b, &op_sbc_a_c, &op_sbc_a_d, &op_sbc_a_e,
			&op_sbc_a_h, &op_sbc_a_l, &op_sbc_a_addr_hl, &op_sbc_a_a,
			// A
			&op_and_b, &op_and_c, &op_and_d, &op_and_e,
			&op_and_h, &op_and_l, &op_and_addr_hl, &op_and_a,
			&op_xor_b, &op_xor_c, &op_xor_d, &op_xor_e,
			&op_xor_h, &op_xor_l, &op_xor_addr_hl, &op_xor_a,
			// B
			&op_or_b, &op_or_c, &op_or_d, &op_or_e,
			&op_or_h, &op_or_l, &op_or_addr_hl, &op_or_a,
			&op_cp_b, &op_cp_c, &op_cp_d, &op_cp_e,
			&op_cp_h, &op_cp_l, &op_cp_addr_hl, &op_cp_a,

			// C
			&op_ret_nz, &op_pop_bc, &op_jp_nz_nn, &op_jp_nn,
			&op_call_nz_nn, &op_push_bc, &op_add_a_n, &op_rst_0,
			&op_ret_z, &op_ret, &op_jp_z_nn, &op_ext_ops,
			&op_call_z_nn, &op_call_nn, &op_adc_a_n, &op_rst_8,
			// D
			&op_ret_nc, &op_pop_de, &op_jp_nc_nn, &op_xx,
			&op_call_nc_nn, &op_push_de, &op_sub_a_n, &op_rst_10,
			&op_ret_c, &op_reti, &op_jp_c_nn, &op_xx,
			&op_call_c_nn, &op_xx, &op_sbc_a_n, &op_rst_18,
			// E
			&op_ldh_addr_n_a, &op_pop_hl, &op_ldh_addr_c_a, &op_xx,
			&op_xx, &op_push_hl, &op_and_n, &op_rst_20,
			&op_add_sp_d, &op_jp_addr_hl, &op_ld_addr_nn_a, &op_xx,
			&op_xx, &op_xx, &op_xor_n, &op_rst_28,
			// F
			&op_ldh_a_addr_n, &op_pop_af, &op_xx, &op_di,
			&op_xx, &op_push_af, &op_or_n, &op_rst_30,
			&op_ldhl_sp_d, &op_ld_sp_hl, &op_ld_a_addr_nn, &op_ei,
			&op_xx, &op_xx, &op_cp_n, &op_rst_38
		];
	}

	void reset() {
	}

	void run_next_operation() {
		u8 opcode = _memory[_pc++];

		// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.3. Commands
		// http://imrannazar.com/Gameboy-Z80-Opcode-Map

	}

	void op_nop() { _ticks += 4; }
	void op_stop() {}
	void op_halt() {}

	// LD r1, r2
	void op_ld_a_a() { _a = _a; _ticks += 4; }
	void op_ld_a_b() { _a = _b; _ticks += 4; }
	void op_ld_a_c() { _a = _c; _ticks += 4; }
	void op_ld_a_d() { _a = _d; _ticks += 4; }
	void op_ld_a_e() { _a = _e; _ticks += 4; }
	void op_ld_a_h() { _a = _h; _ticks += 4; }
	void op_ld_a_l() { _a = _l; _ticks += 4; }
	void op_ld_a_addr_hl() { _a = _memory[_hl]; _ticks += 8; }
	void op_ld_b_a() { _b = _a; _ticks += 4; }
	void op_ld_b_b() { _b = _b; _ticks += 4; }
	void op_ld_b_c() { _b = _c; _ticks += 4; }
	void op_ld_b_d() { _b = _d; _ticks += 4; }
	void op_ld_b_e() { _b = _e; _ticks += 4; }
	void op_ld_b_h() { _b = _h; _ticks += 4; }
	void op_ld_b_l() { _b = _l; _ticks += 4; }
	void op_ld_b_addr_hl() { _b = _memory[_hl]; _ticks += 8; }
	void op_ld_c_a() { _c = _a; _ticks += 4; }
	void op_ld_c_b() { _c = _b; _ticks += 4; }
	void op_ld_c_c() { _c = _c; _ticks += 4; }
	void op_ld_c_d() { _c = _d; _ticks += 4; }
	void op_ld_c_e() { _c = _e; _ticks += 4; }
	void op_ld_c_h() { _c = _h; _ticks += 4; }
	void op_ld_c_l() { _c = _l; _ticks += 4; }
	void op_ld_c_addr_hl() { _c = _memory[_hl]; _ticks += 8; }
	void op_ld_d_a() { _d = _a; _ticks += 4; }
	void op_ld_d_b() { _d = _b; _ticks += 4; }
	void op_ld_d_c() { _d = _c; _ticks += 4; }
	void op_ld_d_d() { _d = _d; _ticks += 4; }
	void op_ld_d_e() { _d = _e; _ticks += 4; }
	void op_ld_d_h() { _d = _h; _ticks += 4; }
	void op_ld_d_l() { _d = _l; _ticks += 4; }
	void op_ld_d_addr_hl() { _d = _memory[_hl]; _ticks += 8; }
	void op_ld_e_a() { _e = _a; _ticks += 4; }
	void op_ld_e_b() { _e = _b; _ticks += 4; }
	void op_ld_e_c() { _e = _c; _ticks += 4; }
	void op_ld_e_d() { _e = _d; _ticks += 4; }
	void op_ld_e_e() { _e = _e; _ticks += 4; }
	void op_ld_e_h() { _e = _h; _ticks += 4; }
	void op_ld_e_l() { _e = _l; _ticks += 4; }
	void op_ld_e_addr_hl() { _e = _memory[_hl]; _ticks += 8; }
	void op_ld_h_a() { _h = _a; _ticks += 4; }
	void op_ld_h_b() { _h = _b; _ticks += 4; }
	void op_ld_h_c() { _h = _c; _ticks += 4; }
	void op_ld_h_d() { _h = _d; _ticks += 4; }
	void op_ld_h_e() { _h = _e; _ticks += 4; }
	void op_ld_h_h() { _h = _h; _ticks += 4; }
	void op_ld_h_l() { _h = _l; _ticks += 4; }
	void op_ld_h_addr_hl() { _h = _memory[_hl]; _ticks += 8; }
	void op_ld_l_a() { _l = _a; _ticks += 4; }
	void op_ld_l_b() { _l = _b; _ticks += 4; }
	void op_ld_l_c() { _l = _c; _ticks += 4; }
	void op_ld_l_d() { _l = _d; _ticks += 4; }
	void op_ld_l_e() { _l = _e; _ticks += 4; }
	void op_ld_l_h() { _l = _h; _ticks += 4; }
	void op_ld_l_l() { _l = _l; _ticks += 4; }
	void op_ld_l_addr_hl() { _l = _memory[_hl]; _ticks += 8; }
	void op_ld_addr_hl_a() { _memory[_hl] = _a; _ticks += 8; }
	void op_ld_addr_hl_b() { _memory[_hl] = _b; _ticks += 8; }
	void op_ld_addr_hl_c() { _memory[_hl] = _c; _ticks += 8; }
	void op_ld_addr_hl_d() { _memory[_hl] = _d; _ticks += 8; }
	void op_ld_addr_hl_e() { _memory[_hl] = _e; _ticks += 8; }
	void op_ld_addr_hl_h() { _memory[_hl] = _h; _ticks += 8; }
	void op_ld_addr_hl_l() { _memory[_hl] = _l; _ticks += 8; }

	// LD nn, n
	void op_ld_a_n() {}
	void op_ld_b_n() {}
	void op_ld_c_n() {}
	void op_ld_d_n() {}
	void op_ld_e_n() {}
	void op_ld_h_n() {}
	void op_ld_l_n() {}

	// PUSH
	void op_push_af() {
		_memory[--_sp] = _a;
		_memory[--_sp] = _f;
		_ticks += 16;
	}
	void op_push_bc() {
		_memory[--_sp] = _b;
		_memory[--_sp] = _c;
		_ticks += 16;
	}
	void op_push_de() {
		_memory[--_sp] = _d;
		_memory[--_sp] = _e;
		_ticks += 16;
	}
	void op_push_hl() {
		_memory[--_sp] = _h;
		_memory[--_sp] = _l;
		_ticks += 16;
	}

	// POP
	void op_pop_af() {
		_f = _memory[_sp++];
		_a = _memory[_sp++];
		_ticks += 12;
	}
	void op_pop_bc() {
		_c = _memory[_sp++];
		_b = _memory[_sp++];
		_ticks += 12;
	}
	void op_pop_de() {
		_e = _memory[_sp++];
		_d = _memory[_sp++];
		_ticks += 12;
	}
	void op_pop_hl() {
		_l = _memory[_sp++];
		_h = _memory[_sp++];
		_ticks += 12;
	}


// 0
	void op_ld_bc_nn() {}
	void op_ld_addr_bc_a() {}
	void op_inc_bc() {}
	void op_inc_b() {}
	void op_dec_b() {}
	void op_rlc_a() {}
	void op_ld_addr_nn_sp() {}
	void op_add_hl_bc() {}
	void op_ld_a_addr_bc() {}
	void op_dec_bc() {}
	void op_inc_c() {}
	void op_dec_c() {}
	void op_rrc_a() {}
	// 1
	void op_ld_de_nn() {}
	void op_ld_addr_de_a() {}
	void op_inc_de() {}
	void op_inc_d() {}
	void op_dec_d() {}
	void op_rl_a() {}
	void op_jr_n() {}
	void op_add_hl_de() {}
	void op_ld_a_addr_de() {}
	void op_dec_de() {}
	void op_inc_e() {}
	void op_dec_e() {}
	void op_rr_a() {}
		// 2
	void op_jr_nz_n() {}
	void op_ld_hl_nn() {}
	void op_ldi_addr_hl_a() {}
	void op_inc_hl() {}
	void op_inc_h() {}
	void op_dec_h() {}
	void op_daa() {}
	void op_jr_z_n() {}
	void op_add_hl_hl() {}
	void op_ldi_a_addr_hl() {}
	void op_dec_hl() {}
	void op_inc_l() {}
	void op_dec_l() {}
	void op_cpl() {}
		// 3
	void op_jr_nc_n() {}
	void op_ld_sp_nn() {}
	void op_ldd_addr_hl_a() {}
	void op_inc_sp() {}
	void op_inc_addr_hl() {}
	void op_dec_addr_hl() {}
	void op_ld_addr_hl_n() {}
	void op_scf() {}
	void op_jr_c_n() {}
	void op_add_hl_sp() {}
	void op_ldd_a_addr_hl() {}
	void op_dec_sp() {}
	void op_inc_a() {}
	void op_dec_a() {}
	void op_ccf() {}

		// 7

		// 8
	void op_add_a_b() {}
	void op_add_a_c() {}
	void op_add_a_d() {}
	void op_add_a_e() {}
	void op_add_a_h() {}
	void op_add_a_l() {}
	void op_add_a_addr_hl() {}
	void op_add_a_a() {}
	void op_adc_a_b() {}
	void op_adc_a_c() {}
	void op_adc_a_d() {}
	void op_adc_a_e() {}
	void op_adc_a_h() {}
	void op_adc_a_l() {}
	void op_adc_a_addr_hl() {}
	void op_adc_a_a() {}
	// 9
	void op_sub_a_b() {}
	void op_sub_a_c() {}
	void op_sub_a_d() {}
	void op_sub_a_e() {}
	void op_sub_a_h() {}
	void op_sub_a_l() {}
	void op_sub_a_addr_hl() {}
	void op_sub_a_a() {}
	void op_sbc_a_b() {}
	void op_sbc_a_c() {}
	void op_sbc_a_d() {}
	void op_sbc_a_e() {}
	void op_sbc_a_h() {}
	void op_sbc_a_l() {}
	void op_sbc_a_addr_hl() {}
	void op_sbc_a_a() {}
		// A
	void op_and_b() {}
	void op_and_c() {}
	void op_and_d() {}
	void op_and_e() {}
	void op_and_h() {}
	void op_and_l() {}
	void op_and_addr_hl() {}
	void op_and_a() {}
	void op_xor_b() {}
	void op_xor_c() {}
	void op_xor_d() {}
	void op_xor_e() {}
	void op_xor_h() {}
	void op_xor_l() {}
	void op_xor_addr_hl() {}
	void op_xor_a() {}
	// B
	void op_or_b() {}
	void op_or_c() {}
	void op_or_d() {}
	void op_or_e() {}
	void op_or_h() {}
	void op_or_l() {}
	void op_or_addr_hl() {}
	void op_or_a() {}
	void op_cp_b() {}
	void op_cp_c() {}
	void op_cp_d() {}
	void op_cp_e() {}
	void op_cp_h() {}
	void op_cp_l() {}
	void op_cp_addr_hl() {}
	void op_cp_a() {}
	// C
	void op_ret_nz() {}
	void op_jp_nz_nn() {}
	void op_jp_nn() {}
	void op_call_nz_nn() {}
	void op_add_a_n() {}
	void op_rst_0() {}
	void op_ret_z() {}
	void op_ret() {}
	void op_jp_z_nn() {}
	void op_ext_ops() {}
	void op_call_z_nn() {}
	void op_call_nn() {}
	void op_adc_a_n() {}
	void op_rst_8() {}
	// D
	void op_ret_nc() {}
	void op_jp_nc_nn() {}
	void op_xx() {}
	void op_call_nc_nn() {}
	void op_sub_a_n() {}
	void op_rst_10() {}
	void op_ret_c() {}
	void op_reti() {}
	void op_jp_c_nn() {}
	//void op_xx() {}
	void op_call_c_nn() {}
	//void op_xx() {}
	void op_sbc_a_n() {}
	void op_rst_18() {}
	// E
	void op_ldh_addr_n_a() {}
	void op_ldh_addr_c_a() {}
	//void op_xx() {}
	//void op_xx() {}
	void op_and_n() {}
	void op_rst_20() {}
	void op_add_sp_d() {}
	void op_jp_addr_hl() {}
	void op_ld_addr_nn_a() {}
	//void op_xx() {}
	//void op_xx() {}
	//void op_xx() {}
	void op_xor_n() {}
	void op_rst_28() {}
		// F
	void op_ldh_a_addr_n() {}
	//void op_xx() {}
	void op_di() {}
	//void op_xx() {}
	void op_or_n() {}
	void op_rst_30() {}
	void op_ldhl_sp_d() {}
	void op_ld_sp_hl() {}
	void op_ld_a_addr_nn() {}
	void op_ei() {}
	//void op_xx() {}
	//void op_xx() {}
	void op_cp_n() {}
	void op_rst_38() {}





		// 0
	void opcb_rlc_b() {}
	void opcb_rlc_c() {}
	void opcb_rlc_d() {}
	void opcb_rlc_e() {}
	void opcb_rlc_h() {}
	void opcb_rlc_l() {}
	void opcb_rlc_hl() {}
	void opcb_rlc_a() {}
	void opcb_rrc_b() {}
	void opcb_rrc_c() {}
	void opcb_rrc_d() {}
	void opcb_rrc_e() {}
	void opcb_rrc_h() {}
	void opcb_rrc_l() {}
	void opcb_rrc_hl() {}
	void opcb_rrc_a() {}
		// 1
	void opcb_rl_b() {}
	void opcb_rl_c() {}
	void opcb_rl_d() {}
	void opcb_rl_e() {}
	void opcb_rl_h() {}
	void opcb_rl_l() {}
	void opcb_rl_hl() {}
	void opcb_rl_a() {}
	void opcb_rr_b() {}
	void opcb_rr_c() {}
	void opcb_rr_d() {}
	void opcb_rr_e() {}
	void opcb_rr_h() {}
	void opcb_rr_l() {}
	void opcb_rr_hl() {}
	void opcb_rr_a() {}
		// 2
	void opcb_sla_b() {}
	void opcb_sla_c() {}
	void opcb_sla_d() {}
	void opcb_sla_e() {}
	void opcb_sla_h() {}
	void opcb_sla_l() {}
	void opcb_sla_hl() {}
	void opcb_sla_a() {}
	void opcb_sra_b() {}
	void opcb_sra_c() {}
	void opcb_sra_d() {}
	void opcb_sra_e() {}
	void opcb_sra_h() {}
	void opcb_sra_l() {}
	void opcb_sra_hl() {}
	void opcb_sra_a() {}
		// 3
	void opcb_swap_b() {}
	void opcb_swap_c() {}
	void opcb_swap_d() {}
	void opcb_swap_e() {}
	void opcb_swap_h() {}
	void opcb_swap_l() {}
	void opcb_swap_hl() {}
	void opcb_swap_a() {}
	void opcb_srl_b() {}
	void opcb_srl_c() {}
	void opcb_srl_d() {}
	void opcb_srl_e() {}
	void opcb_srl_h() {}
	void opcb_srl_l() {}
	void opcb_srl_hl() {}
	void opcb_srl_a() {}
		// 4
	void opcb_bit_0_b() {}
	void opcb_bit_0_c() {}
	void opcb_bit_0_d() {}
	void opcb_bit_0_e() {}
	void opcb_bit_0_h() {}
	void opcb_bit_0_l() {}
	void opcb_bit_0_hl() {}
	void opcb_bit_0_a() {}
	void opcb_bit_1_b() {}
	void opcb_bit_1_c() {}
	void opcb_bit_1_d() {}
	void opcb_bit_1_e() {}
	void opcb_bit_1_h() {}
	void opcb_bit_1_l() {}
	void opcb_bit_1_hl() {}
	void opcb_bit_1_a() {}
		// 5
	void opcb_bit_2_b() {}
	void opcb_bit_2_c() {}
	void opcb_bit_2_d() {}
	void opcb_bit_2_e() {}
	void opcb_bit_2_h() {}
	void opcb_bit_2_l() {}
	void opcb_bit_2_hl() {}
	void opcb_bit_2_a() {}
	void opcb_bit_3_b() {}
	void opcb_bit_3_c() {}
	void opcb_bit_3_d() {}
	void opcb_bit_3_e() {}
	void opcb_bit_3_h() {}
	void opcb_bit_3_l() {}
	void opcb_bit_3_hl() {}
	void opcb_bit_3_a() {}
		// 6
	void opcb_bit_4_b() {}
	void opcb_bit_4_c() {}
	void opcb_bit_4_d() {}
	void opcb_bit_4_e() {}
	void opcb_bit_4_h() {}
	void opcb_bit_4_l() {}
	void opcb_bit_4_hl() {}
	void opcb_bit_4_a() {}
	void opcb_bit_5_b() {}
	void opcb_bit_5_c() {}
	void opcb_bit_5_d() {}
	void opcb_bit_5_e() {}
	void opcb_bit_5_h() {}
	void opcb_bit_5_l() {}
	void opcb_bit_5_hl() {}
	void opcb_bit_5_a() {}
		// 7
	void opcb_bit_6_b() {}
	void opcb_bit_6_c() {}
	void opcb_bit_6_d() {}
	void opcb_bit_6_e() {}
	void opcb_bit_6_h() {}
	void opcb_bit_6_l() {}
	void opcb_bit_6_hl() {}
	void opcb_bit_6_a() {}
	void opcb_bit_7_b() {}
	void opcb_bit_7_c() {}
	void opcb_bit_7_d() {}
	void opcb_bit_7_e() {}
	void opcb_bit_7_h() {}
	void opcb_bit_7_l() {}
	void opcb_bit_7_hl() {}
	void opcb_bit_7_a() {}
		// 8
	void opcb_res_0_b() {}
	void opcb_res_0_c() {}
	void opcb_res_0_d() {}
	void opcb_res_0_e() {}
	void opcb_res_0_h() {}
	void opcb_res_0_l() {}
	void opcb_res_0_hl() {}
	void opcb_res_0_a() {}
	void opcb_res_1_b() {}
	void opcb_res_1_c() {}
	void opcb_res_1_d() {}
	void opcb_res_1_e() {}
	void opcb_res_1_h() {}
	void opcb_res_1_l() {}
	void opcb_res_1_hl() {}
	void opcb_res_1_a() {}
		// 9
	void opcb_res_2_b() {}
	void opcb_res_2_c() {}
	void opcb_res_2_d() {}
	void opcb_res_2_e() {}
	void opcb_res_2_h() {}
	void opcb_res_2_l() {}
	void opcb_res_2_hl() {}
	void opcb_res_2_a() {}
	void opcb_res_3_b() {}
	void opcb_res_3_c() {}
	void opcb_res_3_d() {}
	void opcb_res_3_e() {}
	void opcb_res_3_h() {}
	void opcb_res_3_l() {}
	void opcb_res_3_hl() {}
	void opcb_res_3_a() {}
		// a
	void opcb_res_4_b() {}
	void opcb_res_4_c() {}
	void opcb_res_4_d() {}
	void opcb_res_4_e() {}
	void opcb_res_4_h() {}
	void opcb_res_4_l() {}
	void opcb_res_4_hl() {}
	void opcb_res_4_a() {}
	void opcb_res_5_b() {}
	void opcb_res_5_c() {}
	void opcb_res_5_d() {}
	void opcb_res_5_e() {}
	void opcb_res_5_h() {}
	void opcb_res_5_l() {}
	void opcb_res_5_hl() {}
	void opcb_res_5_a() {}
		// b
	void opcb_res_6_b() {}
	void opcb_res_6_c() {}
	void opcb_res_6_d() {}
	void opcb_res_6_e() {}
	void opcb_res_6_h() {}
	void opcb_res_6_l() {}
	void opcb_res_6_hl() {}
	void opcb_res_6_a() {}
	void opcb_res_7_b() {}
	void opcb_res_7_c() {}
	void opcb_res_7_d() {}
	void opcb_res_7_e() {}
	void opcb_res_7_h() {}
	void opcb_res_7_l() {}
	void opcb_res_7_hl() {}
	void opcb_res_7_a() {}
		// c
	void opcb_set_0_b() {}
	void opcb_set_0_c() {}
	void opcb_set_0_d() {}
	void opcb_set_0_e() {}
	void opcb_set_0_h() {}
	void opcb_set_0_l() {}
	void opcb_set_0_hl() {}
	void opcb_set_0_a() {}
	void opcb_set_1_b() {}
	void opcb_set_1_c() {}
	void opcb_set_1_d() {}
	void opcb_set_1_e() {}
	void opcb_set_1_h() {}
	void opcb_set_1_l() {}
	void opcb_set_1_hl() {}
	void opcb_set_1_a() {}
// d
	void opcb_set_2_b() {}
	void opcb_set_2_c() {}
	void opcb_set_2_d() {}
	void opcb_set_2_e() {}
	void opcb_set_2_h() {}
	void opcb_set_2_l() {}
	void opcb_set_2_hl() {}
	void opcb_set_2_a() {}
	void opcb_set_3_b() {}
	void opcb_set_3_c() {}
	void opcb_set_3_d() {}
	void opcb_set_3_e() {}
	void opcb_set_3_h() {}
	void opcb_set_3_l() {}
	void opcb_set_3_hl() {}
	void opcb_set_3_a() {}
		// e
	void opcb_set_4_b() {}
	void opcb_set_4_c() {}
	void opcb_set_4_d() {}
	void opcb_set_4_e() {}
	void opcb_set_4_h() {}
	void opcb_set_4_l() {}
	void opcb_set_4_hl() {}
	void opcb_set_4_a() {}
	void opcb_set_5_b() {}
	void opcb_set_5_c() {}
	void opcb_set_5_d() {}
	void opcb_set_5_e() {}
	void opcb_set_5_h() {}
	void opcb_set_5_l() {}
	void opcb_set_5_hl() {}
	void opcb_set_5_a() {}
	// F
	void opcb_set_6_b() {}
	void opcb_set_6_c() {}
	void opcb_set_6_d() {}
	void opcb_set_6_e() {}
	void opcb_set_6_h() {}
	void opcb_set_6_l() {}
	void opcb_set_6_hl() {}
	void opcb_set_6_a() {}
	void opcb_set_7_b() {}
	void opcb_set_7_c() {}
	void opcb_set_7_d() {}
	void opcb_set_7_e() {}
	void opcb_set_7_h() {}
	void opcb_set_7_l() {}
	void opcb_set_7_hl() {}
	void opcb_set_7_a() {}
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
