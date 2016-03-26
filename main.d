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
import helpers;


string g_file_name = null;

public class Screen {
	static immutable int x = 160;
	static immutable int y = 144;
	static immutable int width = 160;
	static immutable int height = 144;
}

// https://en.wikipedia.org/wiki/Game_Boy
// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 2.3. Game Boy Specs
// http://www.zilog.com/docs/z80/um0080.pdf
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

	u16 _af() { return u8s_to_u16(_a, _f); }
	u16 _bc() { return u8s_to_u16(_b, _c); }
	u16 _de() { return u8s_to_u16(_d, _e); }
	u16 _hl() { return u8s_to_u16(_h, _l); }

	void _af(u16 value) { u16_to_u8s(value, _a, _f); }
	void _bc(u16 value) { u16_to_u8s(value, _b, _c); }
	void _de(u16 value) { u16_to_u8s(value, _d, _e); }
	void _hl(u16 value) { u16_to_u8s(value, _h, _l); }

	bool is_flag_zero() { return is_bit_set(_f, 7); }
	bool is_flag_subtract() { return is_bit_set(_f, 6); }
	bool is_flag_half_carry() { return is_bit_set(_f, 5); }
	bool is_flag_carry() { return is_bit_set(_f, 4); }

	void is_flag_zero(bool is_set) { set_bit(_f, 7, is_set); }
	void is_flag_subtract(bool is_set) { set_bit(_f, 6, is_set); }
	void is_flag_half_carry(bool is_set) { set_bit(_f, 5, is_set); }
	void is_flag_carry(bool is_set) { set_bit(_f, 4, is_set); }

	u8 read_u8() {
		u8 data = _memory[_pc];
		_pc += 1;
		return data;
	}

	u16 read_u16() {
		u16 data = u8s_to_u16(_memory[_pc], _memory[_pc+1]);
		_pc += 2;
		return data;
	}

	void write_u8(u16 i, u8 value) {
		_memory[i] = value;
	}

	void write_u16(u16 i, u16 value) {
		u8 left;
		u8 right;
		u16_to_u8s(value, left, right);
		_memory[i] = left;
		_memory[i + 1] = right;
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
			// 0
			&opcb_rlc_b, &opcb_rlc_c, &opcb_rlc_d, &opcb_rlc_e,
			&opcb_rlc_h, &opcb_rlc_l, &opcb_rlc_addr_hl, &opcb_rlc_a,
			&opcb_rrc_b, &opcb_rrc_c, &opcb_rrc_d, &opcb_rrc_e,
			&opcb_rrc_h, &opcb_rrc_l, &opcb_rrc_addr_hl, &opcb_rrc_a,
				// 1
			&opcb_rl_b, &opcb_rl_c, &opcb_rl_d, &opcb_rl_e,
			&opcb_rl_h, &opcb_rl_l, &opcb_rl_addr_hl, &opcb_rl_a,
			&opcb_rr_b, &opcb_rr_c, &opcb_rr_d, &opcb_rr_e,
			&opcb_rr_h, &opcb_rr_l, &opcb_rr_addr_hl, &opcb_rr_a,
				// 2
			&opcb_sla_b, &opcb_sla_c, &opcb_sla_d, &opcb_sla_e,
			&opcb_sla_h, &opcb_sla_l, &opcb_sla_addr_hl, &opcb_sla_a,
			&opcb_sra_b, &opcb_sra_c, &opcb_sra_d, &opcb_sra_e,
			&opcb_sra_h, &opcb_sra_l, &opcb_sra_addr_hl, &opcb_sra_a,
				// 3
			&opcb_swap_b, &opcb_swap_c, &opcb_swap_d, &opcb_swap_e,
			&opcb_swap_h, &opcb_swap_l, &opcb_swap_addr_hl, &opcb_swap_a,
			&opcb_srl_b, &opcb_srl_c, &opcb_srl_d, &opcb_srl_e,
			&opcb_srl_h, &opcb_srl_l, &opcb_srl_addr_hl, &opcb_srl_a,
				// 4
			&opcb_bit_0_b, &opcb_bit_0_c, &opcb_bit_0_d, &opcb_bit_0_e,
			&opcb_bit_0_h, &opcb_bit_0_l, &opcb_bit_0_addr_hl, &opcb_bit_0_a,
			&opcb_bit_1_b, &opcb_bit_1_c, &opcb_bit_1_d, &opcb_bit_1_e,
			&opcb_bit_1_h, &opcb_bit_1_l, &opcb_bit_1_addr_hl, &opcb_bit_1_a,
				// 5
			&opcb_bit_2_b, &opcb_bit_2_c, &opcb_bit_2_d, &opcb_bit_2_e,
			&opcb_bit_2_h, &opcb_bit_2_l, &opcb_bit_2_addr_hl, &opcb_bit_2_a,
			&opcb_bit_3_b, &opcb_bit_3_c, &opcb_bit_3_d, &opcb_bit_3_e,
			&opcb_bit_3_h, &opcb_bit_3_l, &opcb_bit_3_addr_hl, &opcb_bit_3_a,
				// 6
			&opcb_bit_4_b, &opcb_bit_4_c, &opcb_bit_4_d, &opcb_bit_4_e,
			&opcb_bit_4_h, &opcb_bit_4_l, &opcb_bit_4_addr_hl, &opcb_bit_4_a,
			&opcb_bit_5_b, &opcb_bit_5_c, &opcb_bit_5_d, &opcb_bit_5_e,
			&opcb_bit_5_h, &opcb_bit_5_l, &opcb_bit_5_addr_hl, &opcb_bit_5_a,
				// 7
			&opcb_bit_6_b, &opcb_bit_6_c, &opcb_bit_6_d, &opcb_bit_6_e,
			&opcb_bit_6_h, &opcb_bit_6_l, &opcb_bit_6_addr_hl, &opcb_bit_6_a,
			&opcb_bit_7_b, &opcb_bit_7_c, &opcb_bit_7_d, &opcb_bit_7_e,
			&opcb_bit_7_h, &opcb_bit_7_l, &opcb_bit_7_addr_hl, &opcb_bit_7_a,
				// 8
			&opcb_res_0_b, &opcb_res_0_c, &opcb_res_0_d, &opcb_res_0_e,
			&opcb_res_0_h, &opcb_res_0_l, &opcb_res_0_addr_hl, &opcb_res_0_a,
			&opcb_res_1_b, &opcb_res_1_c, &opcb_res_1_d, &opcb_res_1_e,
			&opcb_res_1_h, &opcb_res_1_l, &opcb_res_1_addr_hl, &opcb_res_1_a,
				// 9
			&opcb_res_2_b, &opcb_res_2_c, &opcb_res_2_d, &opcb_res_2_e,
			&opcb_res_2_h, &opcb_res_2_l, &opcb_res_2_addr_hl, &opcb_res_2_a,
			&opcb_res_3_b, &opcb_res_3_c, &opcb_res_3_d, &opcb_res_3_e,
			&opcb_res_3_h, &opcb_res_3_l, &opcb_res_3_addr_hl, &opcb_res_3_a,
				// a
			&opcb_res_4_b, &opcb_res_4_c, &opcb_res_4_d, &opcb_res_4_e,
			&opcb_res_4_h, &opcb_res_4_l, &opcb_res_4_addr_hl, &opcb_res_4_a,
			&opcb_res_5_b, &opcb_res_5_c, &opcb_res_5_d, &opcb_res_5_e,
			&opcb_res_5_h, &opcb_res_5_l, &opcb_res_5_addr_hl, &opcb_res_5_a,
				// b
			&opcb_res_6_b, &opcb_res_6_c, &opcb_res_6_d, &opcb_res_6_e,
			&opcb_res_6_h, &opcb_res_6_l, &opcb_res_6_addr_hl, &opcb_res_6_a,
			&opcb_res_7_b, &opcb_res_7_c, &opcb_res_7_d, &opcb_res_7_e,
			&opcb_res_7_h, &opcb_res_7_l, &opcb_res_7_addr_hl, &opcb_res_7_a,
				// c
			&opcb_set_0_b, &opcb_set_0_c, &opcb_set_0_d, &opcb_set_0_e,
			&opcb_set_0_h, &opcb_set_0_l, &opcb_set_0_addr_hl, &opcb_set_0_a,
			&opcb_set_1_b, &opcb_set_1_c, &opcb_set_1_d, &opcb_set_1_e,
			&opcb_set_1_h, &opcb_set_1_l, &opcb_set_1_addr_hl, &opcb_set_1_a,
			// d
			&opcb_set_2_b, &opcb_set_2_c, &opcb_set_2_d, &opcb_set_2_e,
			&opcb_set_2_h, &opcb_set_2_l, &opcb_set_2_addr_hl, &opcb_set_2_a,
			&opcb_set_3_b, &opcb_set_3_c, &opcb_set_3_d, &opcb_set_3_e,
			&opcb_set_3_h, &opcb_set_3_l, &opcb_set_3_addr_hl, &opcb_set_3_a,
				// e
			&opcb_set_4_b, &opcb_set_4_c, &opcb_set_4_d, &opcb_set_4_e,
			&opcb_set_4_h, &opcb_set_4_l, &opcb_set_4_addr_hl, &opcb_set_4_a,
			&opcb_set_5_b, &opcb_set_5_c, &opcb_set_5_d, &opcb_set_5_e,
			&opcb_set_5_h, &opcb_set_5_l, &opcb_set_5_addr_hl, &opcb_set_5_a,
			// F
			&opcb_set_6_b, &opcb_set_6_c, &opcb_set_6_d, &opcb_set_6_e,
			&opcb_set_6_h, &opcb_set_6_l, &opcb_set_6_addr_hl, &opcb_set_6_a,
			&opcb_set_7_b, &opcb_set_7_c, &opcb_set_7_d, &opcb_set_7_e,
			&opcb_set_7_h, &opcb_set_7_l, &opcb_set_7_addr_hl, &opcb_set_7_a
		];

		// http://imrannazar.com/Gameboy-Z80-Opcode-Map
		ops = [
			// 0
			&op_nop, &op_ld_bc_nn, &op_ld_addr_bc_a, &op_inc_bc,
			&op_inc_b, &op_dec_b, &op_ld_b_n, &op_rlc_a,
			&op_ld_addr_nn_sp, &op_add_hl_bc, &op_ld_a_addr_bc, &op_dec_bc,
			&op_inc_c, &op_dec_c, &op_ld_c_n, &op_rrc_a,
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
		u8 opcode = read_u8();
	}

	// http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf # 3.3. Commands
	void op_nop() { _ticks += 4; }
	void op_stop() {  throw new Exception("Not implemented"); }
	void op_halt() {  throw new Exception("Not implemented"); }
	void op_xx() {  throw new Exception("Not implemented"); }
	void op_di() {  throw new Exception("Not implemented"); }
	void op_ei() {  throw new Exception("Not implemented"); }
	void op_reti() {  throw new Exception("Not implemented"); }

	// LD n, n
	void op_ld_a_a() { _a = _a; _ticks += 4; }
	void op_ld_a_b() { _a = _b; _ticks += 4; }
	void op_ld_a_c() { _a = _c; _ticks += 4; }
	void op_ld_a_d() { _a = _d; _ticks += 4; }
	void op_ld_a_e() { _a = _e; _ticks += 4; }
	void op_ld_a_h() { _a = _h; _ticks += 4; }
	void op_ld_a_l() { _a = _l; _ticks += 4; }
	void op_ld_b_a() { _b = _a; _ticks += 4; }
	void op_ld_b_b() { _b = _b; _ticks += 4; }
	void op_ld_b_c() { _b = _c; _ticks += 4; }
	void op_ld_b_d() { _b = _d; _ticks += 4; }
	void op_ld_b_e() { _b = _e; _ticks += 4; }
	void op_ld_b_h() { _b = _h; _ticks += 4; }
	void op_ld_b_l() { _b = _l; _ticks += 4; }
	void op_ld_c_a() { _c = _a; _ticks += 4; }
	void op_ld_c_b() { _c = _b; _ticks += 4; }
	void op_ld_c_c() { _c = _c; _ticks += 4; }
	void op_ld_c_d() { _c = _d; _ticks += 4; }
	void op_ld_c_e() { _c = _e; _ticks += 4; }
	void op_ld_c_h() { _c = _h; _ticks += 4; }
	void op_ld_c_l() { _c = _l; _ticks += 4; }
	void op_ld_d_a() { _d = _a; _ticks += 4; }
	void op_ld_d_b() { _d = _b; _ticks += 4; }
	void op_ld_d_c() { _d = _c; _ticks += 4; }
	void op_ld_d_d() { _d = _d; _ticks += 4; }
	void op_ld_d_e() { _d = _e; _ticks += 4; }
	void op_ld_d_h() { _d = _h; _ticks += 4; }
	void op_ld_d_l() { _d = _l; _ticks += 4; }
	void op_ld_e_a() { _e = _a; _ticks += 4; }
	void op_ld_e_b() { _e = _b; _ticks += 4; }
	void op_ld_e_c() { _e = _c; _ticks += 4; }
	void op_ld_e_d() { _e = _d; _ticks += 4; }
	void op_ld_e_e() { _e = _e; _ticks += 4; }
	void op_ld_e_h() { _e = _h; _ticks += 4; }
	void op_ld_e_l() { _e = _l; _ticks += 4; }
	void op_ld_h_a() { _h = _a; _ticks += 4; }
	void op_ld_h_b() { _h = _b; _ticks += 4; }
	void op_ld_h_c() { _h = _c; _ticks += 4; }
	void op_ld_h_d() { _h = _d; _ticks += 4; }
	void op_ld_h_e() { _h = _e; _ticks += 4; }
	void op_ld_h_h() { _h = _h; _ticks += 4; }
	void op_ld_h_l() { _h = _l; _ticks += 4; }
	void op_ld_l_a() { _l = _a; _ticks += 4; }
	void op_ld_l_b() { _l = _b; _ticks += 4; }
	void op_ld_l_c() { _l = _c; _ticks += 4; }
	void op_ld_l_d() { _l = _d; _ticks += 4; }
	void op_ld_l_e() { _l = _e; _ticks += 4; }
	void op_ld_l_h() { _l = _h; _ticks += 4; }
	void op_ld_l_l() { _l = _l; _ticks += 4; }

	// LD n, (nn)
	void op_ld_a_addr_hl() { _a = _memory[_hl]; _ticks += 8; }
	void op_ld_b_addr_hl() { _b = _memory[_hl]; _ticks += 8; }
	void op_ld_c_addr_hl() { _c = _memory[_hl]; _ticks += 8; }
	void op_ld_d_addr_hl() { _d = _memory[_hl]; _ticks += 8; }
	void op_ld_e_addr_hl() { _e = _memory[_hl]; _ticks += 8; }
	void op_ld_h_addr_hl() { _h = _memory[_hl]; _ticks += 8; }
	void op_ld_l_addr_hl() { _l = _memory[_hl]; _ticks += 8; }
	void op_ld_a_addr_bc() { _a = _memory[_bc]; _ticks += 8; }
	void op_ld_a_addr_de() { _a = _memory[_de]; _ticks += 8; }

	// LD n, (##)
	void op_ld_a_addr_nn() { _a = _memory[read_u16()]; _ticks += 16; }

	// LD nn, nn
	void op_ld_sp_hl() { _hl = _sp; _ticks += 8; }

	// LD nn, #
	void op_ld_a_n() { _a = read_u8(); _ticks += 8; }
	void op_ld_b_n() { _b = read_u8(); _ticks += 8; }
	void op_ld_c_n() { _c = read_u8(); _ticks += 8; }
	void op_ld_d_n() { _d = read_u8(); _ticks += 8; }
	void op_ld_e_n() { _e = read_u8(); _ticks += 8; }
	void op_ld_h_n() { _h = read_u8(); _ticks += 8; }
	void op_ld_l_n() { _l = read_u8(); _ticks += 8; }

	// LD nn, ##
	void op_ld_bc_nn() { _bc = read_u16(); _ticks += 12; }
	void op_ld_de_nn() { _de = read_u16(); _ticks += 12; }
	void op_ld_hl_nn() { _hl = read_u16(); _ticks += 12; }
	void op_ld_sp_nn() { _sp = read_u16(); _ticks += 12; }

	// LD (nn), n
	void op_ld_addr_hl_a() { _memory[_hl] = _a; _ticks += 8; }
	void op_ld_addr_hl_b() { _memory[_hl] = _b; _ticks += 8; }
	void op_ld_addr_hl_c() { _memory[_hl] = _c; _ticks += 8; }
	void op_ld_addr_hl_d() { _memory[_hl] = _d; _ticks += 8; }
	void op_ld_addr_hl_e() { _memory[_hl] = _e; _ticks += 8; }
	void op_ld_addr_hl_h() { _memory[_hl] = _h; _ticks += 8; }
	void op_ld_addr_hl_l() { _memory[_hl] = _l; _ticks += 8; }
	void op_ld_addr_bc_a() { _memory[_bc] = _a; _ticks += 8; }
	void op_ld_addr_de_a() { _memory[_de] = _a; _ticks += 8; }

	// LD (nn), #
	void op_ld_addr_hl_n() { _memory[_hl] = read_u8(); _ticks += 8; }

	// LD (##), n
	void op_ld_addr_nn_a() { _memory[read_u16()] = _a; _ticks += 16; }

	// LD (##), nn
	void op_ld_addr_nn_sp() {
		u16 nn = read_u16();
		write_u16(nn, _sp);
		_ticks += 20;
	}

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

	// ADD
	void op_add_a_n() {
		u8 n = read_u8();
		u8 old_value = _a;
		_a += n;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_a() {
		u8 old_value = _a;
		_a += _a;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_b() {
		u8 old_value = _a;
		_a += _b;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_c() {
		u8 old_value = _a;
		_a += _c;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_d() {
		u8 old_value = _a;
		_a += _d;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_e() {
		u8 old_value = _a;
		_a += _e;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_h() {
		u8 old_value = _a;
		_a += _h;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_l() {
		u8 old_value = _a;
		_a += _l;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_add_a_addr_hl() {
		u8 old_value = _a;
		_a += _memory[_hl];
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 8;
	}

	// ADD nn, #
	void op_add_sp_d() {
		u16 old_value = _sp;
		_sp += cast(s8) read_u8();
		is_flag_zero(false);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _sp > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 16;
	}

	// ADD nn, nn
	void op_add_hl_bc() {
		u16 old_value = _hl;
		_hl = cast(u16) (_hl + _bc);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 0xFFF && _bc > 0xFFF);
		is_flag_carry(old_value + _bc > 0xFFFF);
		_ticks += 8;
	}
	void op_add_hl_de() {
		u16 old_value = _hl;
		_hl = cast(u16) (_hl + _de);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 0xFFF && _de > 0xFFF);
		is_flag_carry(old_value + _de > 0xFFFF);
		_ticks += 8;
	}
	void op_add_hl_hl() {
		u16 old_value = _hl;
		_hl = cast(u16) (_hl + _hl);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 0xFFF && old_value > 0xFFF);
		is_flag_carry(old_value + old_value > 0xFFFF);
		_ticks += 8;
	}
	void op_add_hl_sp() {
		u16 old_value = _hl;
		_hl = cast(u16) (_hl + _sp);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 0xFFF && _sp > 0xFFF);
		is_flag_carry(old_value + _sp > 0xFFFF);
		_ticks += 8;
	}

	// ADC
	void op_adc_a_n() {
		u8 n = read_u8();
		u8 old_value = _a;
		_a += n + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_a() {
		u8 old_value = _a;
		_a += _a + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_b() {
		u8 old_value = _a;
		_a += _b + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_c() {
		u8 old_value = _a;
		_a += _c + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_d() {
		u8 old_value = _a;
		_a += _d + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_e() {
		u8 old_value = _a;
		_a += _e + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_h() {
		u8 old_value = _a;
		_a += _h + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_l() {
		u8 old_value = _a;
		_a += _l + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_adc_a_addr_hl() {
		u8 old_value = _a;
		_a += _memory[_hl] + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(old_value <= 15 && _a > 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 8;
	}

	// SUB
	void op_sub_a_n() {
		u8 old_value = _a;
		_a -= read_u8();
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_a() {
		u8 old_value = _a;
		_a -= _a;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_b() {
		u8 old_value = _a;
		_a -= _b;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_c() {
		u8 old_value = _a;
		_a -= _c;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_d() {
		u8 old_value = _a;
		_a -= _d;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_e() {
		u8 old_value = _a;
		_a -= _e;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_h() {
		u8 old_value = _a;
		_a -= _h;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_l() {
		u8 old_value = _a;
		_a -= _l;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sub_a_addr_hl() {
		u8 old_value = _a;
		_a -= _memory[_hl];
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 8;
	}

	// SBC
	void op_sbc_a_n() {
		u8 n = read_u8();
		u8 old_value = _a;
		_a -= n + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_a() {
		u8 old_value = _a;
		_a -= _a + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_b() {
		u8 old_value = _a;
		_a -= _b + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_c() {
		u8 old_value = _a;
		_a -= _c + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_d() {
		u8 old_value = _a;
		_a -= _d + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_e() {
		u8 old_value = _a;
		_a -= _e + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_h() {
		u8 old_value = _a;
		_a -= _h + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_l() {
		u8 old_value = _a;
		_a -= _l + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 4;
	}
	void op_sbc_a_addr_hl() {
		u8 old_value = _a;
		_a -= _memory[_hl] + is_flag_zero;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(old_value > 15 && _a <= 15);
		is_flag_carry(old_value + old_value > 255);
		_ticks += 8;
	}

	// AND
	void op_and_n() {
		_a &= read_u8();
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_a() {
		_a &= _a;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_b() {
		_a &= _b;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_c() {
		_a &= _c;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_d() {
		_a &= _d;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_e() {
		_a &= _e;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_h() {
		_a &= _h;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_l() {
		_a &= _l;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_and_addr_hl() {
		_a &= _memory[_hl];
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		is_flag_carry(false);
		_ticks += 8;
	}

	// OR
	void op_or_n() {
		_a |= read_u8();
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_a() {
		_a |= _a;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_b() {
		_a |= _b;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_c() {
		_a |= _c;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_d() {
		_a |= _d;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_e() {
		_a |= _e;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_h() {
		_a |= _h;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_l() {
		_a |= _l;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_or_addr_hl() {
		_a |= _memory[_hl];
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}

	// XOR
	void op_xor_n() {
		_a ^= read_u8();
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_a() {
		_a ^= _a;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_b() {
		_a ^= _b;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_c() {
		_a ^= _c;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_d() {
		_a ^= _d;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_e() {
		_a ^= _e;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_h() {
		_a ^= _h;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_l() {
		_a ^= _l;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 4;
	}
	void op_xor_addr_hl() {
		_a ^= _memory[_hl];
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}

	// INC
	void op_inc_a() {
		_a++;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_a == 16);
		_ticks += 4;
	}
	void op_inc_b() {
		_b++;
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_b == 16);
		_ticks += 4;
	}
	void op_inc_c() {
		_c++;
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_c == 16);
		_ticks += 4;
	}
	void op_inc_d() {
		_d++;
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_d == 16);
		_ticks += 4;
	}
	void op_inc_e() {
		_e++;
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_e == 16);
		_ticks += 4;
	}
	void op_inc_h() {
		_h++;
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_h == 16);
		_ticks += 4;
	}
	void op_inc_l() {
		_l++;
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_l == 16);
		_ticks += 4;
	}
	void op_inc_addr_hl() {
		_memory[_hl]++;
		is_flag_zero(_memory[_hl] == 0);
		is_flag_subtract(false);
		is_flag_half_carry(_memory[_hl] == 16);
		_ticks += 12;
	}
	void op_inc_bc() {
		_bc = cast(u16)(_bc + 1);
		_ticks += 8;
	}
	void op_inc_de() {
		_de = cast(u16)(_de + 1);
		_ticks += 8;
	}
	void op_inc_hl() {
		_hl = cast(u16)(_hl + 1);
		_ticks += 8;
	}
	void op_inc_sp() {
		_sp = cast(u16)(_sp + 1);
		_ticks += 8;
	}

	// DEC
	void op_dec_a() {
		_a++;
		is_flag_zero(_a == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a == 15);
		_ticks += 4;
	}
	void op_dec_b() {
		_b++;
		is_flag_zero(_b == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_b == 15);
		_ticks += 4;
	}
	void op_dec_c() {
		_c++;
		is_flag_zero(_c == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_c == 15);
		_ticks += 4;
	}
	void op_dec_d() {
		_d++;
		is_flag_zero(_d == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_d == 15);
		_ticks += 4;
	}
	void op_dec_e() {
		_e++;
		is_flag_zero(_e == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_e == 15);
		_ticks += 4;
	}
	void op_dec_h() {
		_h++;
		is_flag_zero(_h == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_h == 15);
		_ticks += 4;
	}
	void op_dec_l() {
		_l++;
		is_flag_zero(_l == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_l == 15);
		_ticks += 4;
	}
	void op_dec_addr_hl() {
		_memory[_hl]++;
		is_flag_zero(_memory[_hl] == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_memory[_hl] == 15);
		_ticks += 12;
	}
	void op_dec_bc() {
		_bc = cast(u16)(_bc - 1);
		_ticks += 8;
	}
	void op_dec_de() {
		_de = cast(u16)(_de - 1);
		_ticks += 8;
	}
	void op_dec_hl() {
		_hl = cast(u16)(_hl - 1);
		_ticks += 8;
	}
	void op_dec_sp() {
		_sp = cast(u16)(_sp - 1);
		_ticks += 8;
	}

	// JP
	void op_jp_c_nn() {
		if (is_flag_carry()) {
			_pc = _memory[_pc];
		}
		_ticks += 12;
	}
	void op_jp_z_nn() {
		if (is_flag_zero()) {
			_pc = _memory[_pc];
		}
		_ticks += 12;
	}
	void op_jp_nc_nn() {
		if (! is_flag_carry()) {
			_pc = _memory[_pc];
		}
		_ticks += 12;
	}
	void op_jp_nz_nn() {
		if (! is_flag_zero()) {
			_pc = _memory[_pc];
		}
		_ticks += 12;
	}
	void op_jp_nn() {
		_pc = _memory[_pc];
		_ticks += 12;
	}
	void op_jp_addr_hl() {
		_pc = _memory[_hl];
		_ticks += 4;
	}

	// JR
	void op_jr_n() {
		s8 n = _memory[_pc];
		_pc += n;
		_ticks += 8;
	}
	void op_jr_c_n() {
		if (is_flag_carry()) {
			s8 n = _memory[_pc];
			_pc += n;
		}
		_ticks += 8;
	}
	void op_jr_z_n() {
		if (is_flag_zero()) {
			s8 n = _memory[_pc];
			_pc += n;
		}
		_ticks += 8;
	}
	void op_jr_nc_n() {
		if (! is_flag_carry()) {
			s8 n = _memory[_pc];
			_pc += n;
		}
		_ticks += 8;
	}
	void op_jr_nz_n() {
		if (! is_flag_zero()) {
			s8 n = _memory[_pc];
			_pc += n;
		}
		_ticks += 8;
	}

	// CP n
	void op_cp_n() {
		u8 n = read_u8();
		u8 result = cast(u8) (_a - n);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < n);
		_ticks += 4;
	}
	void op_cp_a() {
		u8 result = cast(u8) (_a - _a);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _a);
		_ticks += 4;
	}
	void op_cp_b() {
		u8 result = cast(u8) (_a - _b);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _b);
		_ticks += 4;
	}
	void op_cp_c() {
		u8 result = cast(u8) (_a - _c);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _c);
		_ticks += 4;
	}
	void op_cp_d() {
		u8 result = cast(u8) (_a - _d);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _d);
		_ticks += 4;
	}
	void op_cp_e() {
		u8 result = cast(u8) (_a - _e);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _e);
		_ticks += 4;
	}
	void op_cp_h() {
		u8 result = cast(u8) (_a - _h);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _h);
		_ticks += 4;
	}
	void op_cp_l() {
		u8 result = cast(u8) (_a - _l);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < _l);
		_ticks += 4;
	}
	void op_cp_addr_hl() {
		u8 n = _memory[_hl];
		u8 result = cast(u8) (_a - n);

		is_flag_zero(result == 0);
		is_flag_subtract(true);
		is_flag_half_carry(_a > 15 && result <= 15);
		is_flag_carry(_a < n);
		_ticks += 8;
	}

	// CALL ##
	void op_call_nn() {
		u16 nn = read_u16();
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = nn;
		_ticks += 12;
	}
	void op_call_nz_nn() {
		if (! is_flag_zero()) {
			u16 nn = read_u16();
			u8 npc1, npc2;
			u16_to_u8s(_pc, npc1, npc2);
			_memory[--_sp] = npc1;
			_memory[--_sp] = npc2;
			_pc = nn;
			_ticks += 12;
		}
	}
	void op_call_z_nn() {
		if (is_flag_zero()) {
			u16 nn = read_u16();
			u8 npc1, npc2;
			u16_to_u8s(_pc, npc1, npc2);
			_memory[--_sp] = npc1;
			_memory[--_sp] = npc2;
			_pc = nn;
			_ticks += 12;
		}
	}
	void op_call_nc_nn() {
		if (! is_flag_carry()) {
			u16 nn = read_u16();
			u8 npc1, npc2;
			u16_to_u8s(_pc, npc1, npc2);
			_memory[--_sp] = npc1;
			_memory[--_sp] = npc2;
			_pc = nn;
			_ticks += 12;
		}
	}
	void op_call_c_nn() {
		if (is_flag_carry()) {
			u16 nn = read_u16();
			u8 npc1, npc2;
			u16_to_u8s(_pc, npc1, npc2);
			_memory[--_sp] = npc1;
			_memory[--_sp] = npc2;
			_pc = nn;
			_ticks += 12;
		}
	}

	// RET
	void op_ret() {
		u8 a = _memory[_sp++];
		u8 b = _memory[_sp++];
		_pc = u8s_to_u16(a, b);
		_ticks += 8;
	}
	void op_ret_nc() {
		if (! is_flag_carry()) {
			u8 a = _memory[_sp++];
			u8 b = _memory[_sp++];
			_pc = u8s_to_u16(a, b);
		}
		_ticks += 8;
	}
	void op_ret_c() {
		if (is_flag_carry()) {
			u8 a = _memory[_sp++];
			u8 b = _memory[_sp++];
			_pc = u8s_to_u16(a, b);
		}
		_ticks += 8;
	}
	void op_ret_nz() {
		if (! is_flag_zero()) {
			u8 a = _memory[_sp++];
			u8 b = _memory[_sp++];
			_pc = u8s_to_u16(a, b);
		}
		_ticks += 8;
	}
	void op_ret_z() {
		if (is_flag_zero()) {
			u8 a = _memory[_sp++];
			u8 b = _memory[_sp++];
			_pc = u8s_to_u16(a, b);
		}
		_ticks += 8;
	}

	// RST
	void op_rst_0() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0000;
		_ticks += 32;
	}
	void op_rst_8() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0008;
		_ticks += 32;
	}
	void op_rst_10() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0010;
		_ticks += 32;
	}
	void op_rst_18() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0018;
		_ticks += 32;
	}
	void op_rst_20() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0020;
		_ticks += 32;
	}
	void op_rst_28() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0028;
		_ticks += 32;
	}
	void op_rst_30() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0030;
		_ticks += 32;
	}
	void op_rst_38() {
		u8 npc1, npc2;
		u16_to_u8s(_pc, npc1, npc2);
		_memory[--_sp] = npc1;
		_memory[--_sp] = npc2;
		_pc = 0X0038;
		_ticks += 32;
	}

	// CCF
	void op_ccf() {
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(! is_flag_carry);
		_ticks += 4;
	}

	// SCF
	void op_scf() {
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(true);
		_ticks += 4;
	}

	// DAA
	void op_daa() {
		// Convert A to BCD
		// https://en.wikipedia.org/wiki/Binary-coded_decimal#Basics
		u8 old_value = _a;
		if (_a > 99) _a = 99;
		u8 first = _a / 10;
		u8 second = cast(u8) (_a - (first * 10));
		_a = cast(u8) (first << 8 | second);

		is_flag_zero(_a == 0);
		is_flag_half_carry(false);
		// FIXME: "Set or reset according to operation." pg 95
		// What operation?
		//is_flag_carry(old_value + _bc > 0xFFFF);
		_ticks += 4;
	}

	// CPL
	void op_cpl() {
		_a = ~_a;
		is_flag_subtract(true);
		is_flag_half_carry(true);
		_ticks += 4;
	}

	// LDD
	void op_ldd_a_addr_hl() {
		_a = _memory[_hl];
		_hl = cast(u16) (_hl - 1);
		_ticks += 8;
	}
	void op_ldd_addr_hl_a() {
		_memory[_hl] = _a;
		_hl = cast(u16) (_hl - 1);
		_ticks += 8;
	}

	// LDI
	void op_ldi_a_addr_hl() {
		_a = _memory[_hl];
		_hl = cast(u16) (_hl + 1);
		_ticks += 8;
	}
	void op_ldi_addr_hl_a() {
		_memory[_hl] = _a;
		_hl = cast(u16) (_hl + 1);
		_ticks += 8;
	}

	// LDH
	void op_ldh_a_addr_n() {
		u8 n = read_u8();
		_a = _memory[0xFF00 + n];
		_ticks += 12;
	}
	void op_ldh_addr_c_a() {
		_memory[0xFF00 + _c] = _a;
		_ticks += 8;
	}
	void op_ldh_addr_n_a() {
		u8 n = read_u8();
		_memory[0xFF00 + n] = _a;
		_ticks += 12;
	}
	void op_ldhl_sp_d() {
		s8 n = read_u8();
		_hl = cast(u16) (_sp + n);

		is_flag_zero(false);
		is_flag_subtract(false);
		// FIXME: "Set or reset according to operation"
		// What?
		// is_flag_half_carry(false);
		// is_flag_carry(! is_flag_carry);
		_ticks += 12;
	}

	void op_rr_a() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_a & 0xFFFE) > 0);
		_a = _a >> 1;
		_a |= old_carry;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void op_rl_a() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_a & 0xEFFF) > 0);
		_a = cast(u8) (_a << 1);
		_a |= old_carry;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 4;
	}
	// http://www.zilog.com/docs/z80/um0080.pdf
	void op_rlc_a() {
		u8 old_bit_7 = _a & 0xEFFF;
		_a = cast(u8) (_a << 1);
		_a |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 4;
	}
	void op_rrc_a() {
		u8 old_bit_0 = _a & 0xFFFE;
		_a = cast(u8) (_a >> 1);
		_a |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 4;
	}

	void op_ext_ops() {
		u16 i = read_u16();
		opcbs[i]();
	}

	// BIT
	void opcb_bit_0_a() {
		bool is_set = is_bit_set(_a, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_b() {
		bool is_set = is_bit_set(_b, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_c() {
		bool is_set = is_bit_set(_c, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_d() {
		bool is_set = is_bit_set(_d, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_e() {
		bool is_set = is_bit_set(_e, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_h() {
		bool is_set = is_bit_set(_h, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_l() {
		bool is_set = is_bit_set(_l, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_0_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 0);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}
	void opcb_bit_1_a() {
		bool is_set = is_bit_set(_a, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_b() {
		bool is_set = is_bit_set(_b, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_c() {
		bool is_set = is_bit_set(_c, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_d() {
		bool is_set = is_bit_set(_d, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_e() {
		bool is_set = is_bit_set(_e, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_h() {
		bool is_set = is_bit_set(_h, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_l() {
		bool is_set = is_bit_set(_l, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_1_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 1);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}
	void opcb_bit_2_a() {
		bool is_set = is_bit_set(_a, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_b() {
		bool is_set = is_bit_set(_b, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_c() {
		bool is_set = is_bit_set(_c, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_d() {
		bool is_set = is_bit_set(_d, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_e() {
		bool is_set = is_bit_set(_e, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_h() {
		bool is_set = is_bit_set(_h, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_l() {
		bool is_set = is_bit_set(_l, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_2_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 2);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}

	void opcb_bit_3_a() {
		bool is_set = is_bit_set(_a, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_b() {
		bool is_set = is_bit_set(_b, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_c() {
		bool is_set = is_bit_set(_c, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_d() {
		bool is_set = is_bit_set(_d, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_e() {
		bool is_set = is_bit_set(_e, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_h() {
		bool is_set = is_bit_set(_h, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_l() {
		bool is_set = is_bit_set(_l, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_3_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 3);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}

	void opcb_bit_4_a() {
		bool is_set = is_bit_set(_a, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_b() {
		bool is_set = is_bit_set(_b, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_c() {
		bool is_set = is_bit_set(_c, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_d() {
		bool is_set = is_bit_set(_d, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_e() {
		bool is_set = is_bit_set(_e, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_h() {
		bool is_set = is_bit_set(_h, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_l() {
		bool is_set = is_bit_set(_l, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_4_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 4);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}

	void opcb_bit_5_a() {
		bool is_set = is_bit_set(_a, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_b() {
		bool is_set = is_bit_set(_b, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_c() {
		bool is_set = is_bit_set(_c, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_d() {
		bool is_set = is_bit_set(_d, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_e() {
		bool is_set = is_bit_set(_e, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_h() {
		bool is_set = is_bit_set(_h, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_l() {
		bool is_set = is_bit_set(_l, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_5_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 5);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}

	void opcb_bit_6_a() {
		bool is_set = is_bit_set(_a, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_b() {
		bool is_set = is_bit_set(_b, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_c() {
		bool is_set = is_bit_set(_c, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_d() {
		bool is_set = is_bit_set(_d, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_e() {
		bool is_set = is_bit_set(_e, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_h() {
		bool is_set = is_bit_set(_h, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_l() {
		bool is_set = is_bit_set(_l, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_6_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 6);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}

	void opcb_bit_7_a() {
		bool is_set = is_bit_set(_a, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_b() {
		bool is_set = is_bit_set(_b, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_c() {
		bool is_set = is_bit_set(_c, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_d() {
		bool is_set = is_bit_set(_d, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_e() {
		bool is_set = is_bit_set(_e, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_h() {
		bool is_set = is_bit_set(_h, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_l() {
		bool is_set = is_bit_set(_l, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 8;
	}
	void opcb_bit_7_addr_hl() {
		u8 n = _memory[_hl];
		bool is_set = is_bit_set(n, 7);
		is_flag_zero(is_set == false);
		is_flag_subtract(false);
		is_flag_half_carry(true);
		_ticks += 16;
	}

	// SET
	void opcb_set_0_a() { set_bit(_a, 0, true); _ticks += 8; }
	void opcb_set_0_b() { set_bit(_b, 0, true); _ticks += 8; }
	void opcb_set_0_c() { set_bit(_c, 0, true); _ticks += 8; }
	void opcb_set_0_d() { set_bit(_d, 0, true); _ticks += 8; }
	void opcb_set_0_e() { set_bit(_e, 0, true); _ticks += 8; }
	void opcb_set_0_h() { set_bit(_h, 0, true); _ticks += 8; }
	void opcb_set_0_l() { set_bit(_l, 0, true); _ticks += 8; }
	void opcb_set_0_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 0, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_1_a() { set_bit(_a, 1, true); _ticks += 8; }
	void opcb_set_1_b() { set_bit(_b, 1, true); _ticks += 8; }
	void opcb_set_1_c() { set_bit(_c, 1, true); _ticks += 8; }
	void opcb_set_1_d() { set_bit(_d, 1, true); _ticks += 8; }
	void opcb_set_1_e() { set_bit(_e, 1, true); _ticks += 8; }
	void opcb_set_1_h() { set_bit(_h, 1, true); _ticks += 8; }
	void opcb_set_1_l() { set_bit(_l, 1, true); _ticks += 8; }
	void opcb_set_1_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 1, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_2_a() { set_bit(_a, 2, true); _ticks += 8; }
	void opcb_set_2_b() { set_bit(_b, 2, true); _ticks += 8; }
	void opcb_set_2_c() { set_bit(_c, 2, true); _ticks += 8; }
	void opcb_set_2_d() { set_bit(_d, 2, true); _ticks += 8; }
	void opcb_set_2_e() { set_bit(_e, 2, true); _ticks += 8; }
	void opcb_set_2_h() { set_bit(_h, 2, true); _ticks += 8; }
	void opcb_set_2_l() { set_bit(_l, 2, true); _ticks += 8; }
	void opcb_set_2_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 2, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_3_a() { set_bit(_a, 3, true); _ticks += 8; }
	void opcb_set_3_b() { set_bit(_b, 3, true); _ticks += 8; }
	void opcb_set_3_c() { set_bit(_c, 3, true); _ticks += 8; }
	void opcb_set_3_d() { set_bit(_d, 3, true); _ticks += 8; }
	void opcb_set_3_e() { set_bit(_e, 3, true); _ticks += 8; }
	void opcb_set_3_h() { set_bit(_h, 3, true); _ticks += 8; }
	void opcb_set_3_l() { set_bit(_l, 3, true); _ticks += 8; }
	void opcb_set_3_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 3, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_4_a() { set_bit(_a, 4, true); _ticks += 8; }
	void opcb_set_4_b() { set_bit(_b, 4, true); _ticks += 8; }
	void opcb_set_4_c() { set_bit(_c, 4, true); _ticks += 8; }
	void opcb_set_4_d() { set_bit(_d, 4, true); _ticks += 8; }
	void opcb_set_4_e() { set_bit(_e, 4, true); _ticks += 8; }
	void opcb_set_4_h() { set_bit(_h, 4, true); _ticks += 8; }
	void opcb_set_4_l() { set_bit(_l, 4, true); _ticks += 8; }
	void opcb_set_4_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 4, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_5_a() { set_bit(_a, 5, true); _ticks += 8; }
	void opcb_set_5_b() { set_bit(_b, 5, true); _ticks += 8; }
	void opcb_set_5_c() { set_bit(_c, 5, true); _ticks += 8; }
	void opcb_set_5_d() { set_bit(_d, 5, true); _ticks += 8; }
	void opcb_set_5_e() { set_bit(_e, 5, true); _ticks += 8; }
	void opcb_set_5_h() { set_bit(_h, 5, true); _ticks += 8; }
	void opcb_set_5_l() { set_bit(_l, 5, true); _ticks += 8; }
	void opcb_set_5_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 5, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_6_a() { set_bit(_a, 6, true); _ticks += 8; }
	void opcb_set_6_b() { set_bit(_b, 6, true); _ticks += 8; }
	void opcb_set_6_c() { set_bit(_c, 6, true); _ticks += 8; }
	void opcb_set_6_d() { set_bit(_d, 6, true); _ticks += 8; }
	void opcb_set_6_e() { set_bit(_e, 6, true); _ticks += 8; }
	void opcb_set_6_h() { set_bit(_h, 6, true); _ticks += 8; }
	void opcb_set_6_l() { set_bit(_l, 6, true); _ticks += 8; }
	void opcb_set_6_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 6, true); _memory[_hl] = n; _ticks += 16; }
	void opcb_set_7_a() { set_bit(_a, 7, true); _ticks += 8; }
	void opcb_set_7_b() { set_bit(_b, 7, true); _ticks += 8; }
	void opcb_set_7_c() { set_bit(_c, 7, true); _ticks += 8; }
	void opcb_set_7_d() { set_bit(_d, 7, true); _ticks += 8; }
	void opcb_set_7_e() { set_bit(_e, 7, true); _ticks += 8; }
	void opcb_set_7_h() { set_bit(_h, 7, true); _ticks += 8; }
	void opcb_set_7_l() { set_bit(_l, 7, true); _ticks += 8; }
	void opcb_set_7_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 7, true); _memory[_hl] = n; _ticks += 16; }

	// RES
	void opcb_res_0_a() { set_bit(_a, 0, false); _ticks += 8; }
	void opcb_res_0_b() { set_bit(_b, 0, false); _ticks += 8; }
	void opcb_res_0_c() { set_bit(_c, 0, false); _ticks += 8; }
	void opcb_res_0_d() { set_bit(_d, 0, false); _ticks += 8; }
	void opcb_res_0_e() { set_bit(_e, 0, false); _ticks += 8; }
	void opcb_res_0_h() { set_bit(_h, 0, false); _ticks += 8; }
	void opcb_res_0_l() { set_bit(_l, 0, false); _ticks += 8; }
	void opcb_res_0_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 0, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_1_a() { set_bit(_a, 1, false); _ticks += 8; }
	void opcb_res_1_b() { set_bit(_b, 1, false); _ticks += 8; }
	void opcb_res_1_c() { set_bit(_c, 1, false); _ticks += 8; }
	void opcb_res_1_d() { set_bit(_d, 1, false); _ticks += 8; }
	void opcb_res_1_e() { set_bit(_e, 1, false); _ticks += 8; }
	void opcb_res_1_h() { set_bit(_h, 1, false); _ticks += 8; }
	void opcb_res_1_l() { set_bit(_l, 1, false); _ticks += 8; }
	void opcb_res_1_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 1, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_2_a() { set_bit(_a, 2, false); _ticks += 8; }
	void opcb_res_2_b() { set_bit(_b, 2, false); _ticks += 8; }
	void opcb_res_2_c() { set_bit(_c, 2, false); _ticks += 8; }
	void opcb_res_2_d() { set_bit(_d, 2, false); _ticks += 8; }
	void opcb_res_2_e() { set_bit(_e, 2, false); _ticks += 8; }
	void opcb_res_2_h() { set_bit(_h, 2, false); _ticks += 8; }
	void opcb_res_2_l() { set_bit(_l, 2, false); _ticks += 8; }
	void opcb_res_2_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 2, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_3_a() { set_bit(_a, 3, false); _ticks += 8; }
	void opcb_res_3_b() { set_bit(_b, 3, false); _ticks += 8; }
	void opcb_res_3_c() { set_bit(_c, 3, false); _ticks += 8; }
	void opcb_res_3_d() { set_bit(_d, 3, false); _ticks += 8; }
	void opcb_res_3_e() { set_bit(_e, 3, false); _ticks += 8; }
	void opcb_res_3_h() { set_bit(_h, 3, false); _ticks += 8; }
	void opcb_res_3_l() { set_bit(_l, 3, false); _ticks += 8; }
	void opcb_res_3_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 3, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_4_a() { set_bit(_a, 4, false); _ticks += 8; }
	void opcb_res_4_b() { set_bit(_b, 4, false); _ticks += 8; }
	void opcb_res_4_c() { set_bit(_c, 4, false); _ticks += 8; }
	void opcb_res_4_d() { set_bit(_d, 4, false); _ticks += 8; }
	void opcb_res_4_e() { set_bit(_e, 4, false); _ticks += 8; }
	void opcb_res_4_h() { set_bit(_h, 4, false); _ticks += 8; }
	void opcb_res_4_l() { set_bit(_l, 4, false); _ticks += 8; }
	void opcb_res_4_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 4, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_5_a() { set_bit(_a, 5, false); _ticks += 8; }
	void opcb_res_5_b() { set_bit(_b, 5, false); _ticks += 8; }
	void opcb_res_5_c() { set_bit(_c, 5, false); _ticks += 8; }
	void opcb_res_5_d() { set_bit(_d, 5, false); _ticks += 8; }
	void opcb_res_5_e() { set_bit(_e, 5, false); _ticks += 8; }
	void opcb_res_5_h() { set_bit(_h, 5, false); _ticks += 8; }
	void opcb_res_5_l() { set_bit(_l, 5, false); _ticks += 8; }
	void opcb_res_5_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 5, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_6_a() { set_bit(_a, 6, false); _ticks += 8; }
	void opcb_res_6_b() { set_bit(_b, 6, false); _ticks += 8; }
	void opcb_res_6_c() { set_bit(_c, 6, false); _ticks += 8; }
	void opcb_res_6_d() { set_bit(_d, 6, false); _ticks += 8; }
	void opcb_res_6_e() { set_bit(_e, 6, false); _ticks += 8; }
	void opcb_res_6_h() { set_bit(_h, 6, false); _ticks += 8; }
	void opcb_res_6_l() { set_bit(_l, 6, false); _ticks += 8; }
	void opcb_res_6_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 6, false); _memory[_hl] = n; _ticks += 16; }
	void opcb_res_7_a() { set_bit(_a, 7, false); _ticks += 8; }
	void opcb_res_7_b() { set_bit(_b, 7, false); _ticks += 8; }
	void opcb_res_7_c() { set_bit(_c, 7, false); _ticks += 8; }
	void opcb_res_7_d() { set_bit(_d, 7, false); _ticks += 8; }
	void opcb_res_7_e() { set_bit(_e, 7, false); _ticks += 8; }
	void opcb_res_7_h() { set_bit(_h, 7, false); _ticks += 8; }
	void opcb_res_7_l() { set_bit(_l, 7, false); _ticks += 8; }
	void opcb_res_7_addr_hl() { u8 n = _memory[_hl]; set_bit(n, 7, false); _memory[_hl] = n; _ticks += 16; }

	// SWAP
	void opcb_swap_a() {
		u8 right = cast(u8) (_a << 8);
		u8 left = cast(u8) (_a >> 8);
		_a = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_b() {
		u8 right = cast(u8) (_b << 8);
		u8 left = cast(u8) (_b >> 8);
		_b = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_c() {
		u8 right = cast(u8) (_c << 8);
		u8 left = cast(u8) (_c >> 8);
		_c = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_d() {
		u8 right = cast(u8) (_d << 8);
		u8 left = cast(u8) (_d >> 8);
		_d = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_e() {
		u8 right = cast(u8) (_e << 8);
		u8 left = cast(u8) (_e >> 8);
		_e = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_h() {
		u8 right = cast(u8) (_h << 8);
		u8 left = cast(u8) (_h >> 8);
		_h = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_l() {
		u8 right = cast(u8) (_l << 8);
		u8 left = cast(u8) (_l >> 8);
		_l = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 8;
	}
	void opcb_swap_addr_hl() {
		u8 n = _memory[_hl];
		u8 right = cast(u8) (n << 8);
		u8 left = cast(u8) (n >> 8);
		_memory[_hl] = right | left;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(false);
		_ticks += 16;
	}

	// RLC
	void opcb_rlc_a() {
		u8 old_bit_7 = _a & 0xEFFF;
		_a = cast(u8) (_a << 1);
		_a |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_b() {
		u8 old_bit_7 = _b & 0xEFFF;
		_b = cast(u8) (_b << 1);
		_b |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_c() {
		u8 old_bit_7 = _c & 0xEFFF;
		_c = cast(u8) (_c << 1);
		_c |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_d() {
		u8 old_bit_7 = _d & 0xEFFF;
		_d = cast(u8) (_d << 1);
		_d |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_e() {
		u8 old_bit_7 = _e & 0xEFFF;
		_e = cast(u8) (_e << 1);
		_e |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_h() {
		u8 old_bit_7 = _h & 0xEFFF;
		_h = cast(u8) (_h << 1);
		_h |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_l() {
		u8 old_bit_7 = _l & 0xEFFF;
		_l = cast(u8) (_l << 1);
		_l |= (old_bit_7 >> 7);
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rlc_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_bit_7 = n & 0xEFFF;
		n = cast(u8) (n << 1);
		n |= (old_bit_7 >> 7);
		_memory[_hl] = n;
		is_flag_carry(old_bit_7 > 0);
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 16;
	}

	// RRC
	void opcb_rrc_a() {
		u8 old_bit_0 = _a & 0xFFFE;
		_a = cast(u8) (_a >> 1);
		_a |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_b() {
		u8 old_bit_0 = _b & 0xFFFE;
		_b = cast(u8) (_b >> 1);
		_b |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_c() {
		u8 old_bit_0 = _c & 0xFFFE;
		_c = cast(u8) (_c >> 1);
		_c |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_d() {
		u8 old_bit_0 = _d & 0xFFFE;
		_d = cast(u8) (_d >> 1);
		_d |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_e() {
		u8 old_bit_0 = _e & 0xFFFE;
		_e = cast(u8) (_e >> 1);
		_e |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_h() {
		u8 old_bit_0 = _h & 0xFFFE;
		_h = cast(u8) (_h >> 1);
		_h |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_l() {
		u8 old_bit_0 = _l & 0xFFFE;
		_l = cast(u8) (_l >> 1);
		_l |= (old_bit_0 << 7);
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rrc_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_bit_0 = n & 0xFFFE;
		n = cast(u8) (n >> 1);
		n |= (old_bit_0 << 7);
		_memory[_hl] = n;
		is_flag_carry(old_bit_0 > 0);
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 16;
	}

	// RL
	void opcb_rl_a() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_a & 0xEFFF) > 0);
		_a = cast(u8) (_a << 1);
		_a |= old_carry;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_b() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_b & 0xEFFF) > 0);
		_b = cast(u8) (_b << 1);
		_b |= old_carry;
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_c() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_c & 0xEFFF) > 0);
		_c = cast(u8) (_c << 1);
		_c |= old_carry;
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_d() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_d & 0xEFFF) > 0);
		_d = cast(u8) (_d << 1);
		_d |= old_carry;
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_e() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_e & 0xEFFF) > 0);
		_e = cast(u8) (_e << 1);
		_e |= old_carry;
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_h() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_h & 0xEFFF) > 0);
		_h = cast(u8) (_h << 1);
		_h |= old_carry;
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_l() {
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((_l & 0xEFFF) > 0);
		_l = cast(u8) (_l << 1);
		_l |= old_carry;
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rl_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_carry = is_flag_carry ? 0x01 : 0x00;
		is_flag_carry((n & 0xEFFF) > 0);
		n = cast(u8) (n << 1);
		n |= old_carry;
		_memory[_hl] = n;
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 16;
	}

	// RR
	void opcb_rr_a() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_a & 0xFFFE) > 0);
		_a = _a >> 1;
		_a |= old_carry;
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_b() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_b & 0xFFFE) > 0);
		_b = _b >> 1;
		_b |= old_carry;
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_c() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_c & 0xFFFE) > 0);
		_c = _c >> 1;
		_c |= old_carry;
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_d() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_d & 0xFFFE) > 0);
		_d = _d >> 1;
		_d |= old_carry;
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_e() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_e & 0xFFFE) > 0);
		_e = _e >> 1;
		_e |= old_carry;
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_h() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_h & 0xFFFE) > 0);
		_h = _h >> 1;
		_h |= old_carry;
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_l() {
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((_l & 0xFFFE) > 0);
		_l = _l >> 1;
		_l |= old_carry;
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 8;
	}
	void opcb_rr_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_carry = is_flag_carry ? 0x80 : 0x00;
		is_flag_carry((n & 0xFFFE) > 0);
		n = n >> 1;
		n |= old_carry;
		_memory[_hl] = n;
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		_ticks += 16;
	}


	// SLA
	void opcb_sla_a() {
		u8 old_bit_7 = _a & 0xEFFF;
		_a = old_bit_7 | cast(u8) (_a << 1);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_b() {
		u8 old_bit_7 = _b & 0xEFFF;
		_b = old_bit_7 | cast(u8) (_b << 1);
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_c() {
		u8 old_bit_7 = _c & 0xEFFF;
		_c = old_bit_7 | cast(u8) (_c << 1);
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_d() {
		u8 old_bit_7 = _d & 0xEFFF;
		_d = old_bit_7 | cast(u8) (_d << 1);
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_e() {
		u8 old_bit_7 = _e & 0xEFFF;
		_e = old_bit_7 | cast(u8) (_e << 1);
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_h() {
		u8 old_bit_7 = _h & 0xEFFF;
		_h = old_bit_7 | cast(u8) (_h << 1);
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_l() {
		u8 old_bit_7 = _l & 0xEFFF;
		_l = old_bit_7 | cast(u8) (_l << 1);
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 8;
	}
	void opcb_sla_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_bit_7 = n & 0xEFFF;
		n = old_bit_7 | cast(u8) (n << 1);
		_memory[_hl] = n;
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_7 > 0);
		_ticks += 16;
	}

	// SRA
	void opcb_sra_a() {
		u8 old_bit_0 = _a & 0xFFFE;
		_a = old_bit_0 | cast(u8) (_a >> 1);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_b() {
		u8 old_bit_0 = _b & 0xFFFE;
		_b = old_bit_0 | cast(u8) (_b >> 1);
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_c() {
		u8 old_bit_0 = _c & 0xFFFE;
		_c = old_bit_0 | cast(u8) (_c >> 1);
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_d() {
		u8 old_bit_0 = _d & 0xFFFE;
		_d = old_bit_0 | cast(u8) (_d >> 1);
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_e() {
		u8 old_bit_0 = _e & 0xFFFE;
		_e = old_bit_0 | cast(u8) (_e >> 1);
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_h() {
		u8 old_bit_0 = _h & 0xFFFE;
		_h = old_bit_0 | cast(u8) (_h >> 1);
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_l() {
		u8 old_bit_0 = _l & 0xFFFE;
		_l = old_bit_0 | cast(u8) (_l >> 1);
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_sra_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_bit_0 = n & 0xFFFE;
		n = old_bit_0 | cast(u8) (n >> 1);
		_memory[_hl] = n;
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 16;
	}

	// SRL
	void opcb_srl_a() {
		u8 old_bit_0 = _a & 0xFFFE;
		_a = cast(u8) (_a >> 1);
		is_flag_zero(_a == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_b() {
		u8 old_bit_0 = _b & 0xFFFE;
		_b = cast(u8) (_b >> 1);
		is_flag_zero(_b == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_c() {
		u8 old_bit_0 = _c & 0xFFFE;
		_c = cast(u8) (_c >> 1);
		is_flag_zero(_c == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_d() {
		u8 old_bit_0 = _d & 0xFFFE;
		_d = cast(u8) (_d >> 1);
		is_flag_zero(_d == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_e() {
		u8 old_bit_0 = _e & 0xFFFE;
		_e = cast(u8) (_e >> 1);
		is_flag_zero(_e == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_h() {
		u8 old_bit_0 = _h & 0xFFFE;
		_h = cast(u8) (_h >> 1);
		is_flag_zero(_h == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_l() {
		u8 old_bit_0 = _l & 0xFFFE;
		_l = cast(u8) (_l >> 1);
		is_flag_zero(_l == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 8;
	}
	void opcb_srl_addr_hl() {
		u8 n = _memory[_hl];
		u8 old_bit_0 = n & 0xFFFE;
		n = cast(u8) (n >> 1);
		_memory[_hl] = n;
		is_flag_zero(n == 0);
		is_flag_subtract(false);
		is_flag_half_carry(false);
		is_flag_carry(old_bit_0 > 0);
		_ticks += 16;
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
