
module helpers;

import types;

pure u16 u8s_to_u16(immutable u8 left, immutable u8 right) {
	return (left << 8) | right;
}

pure void u16_to_u8s(immutable u16 value, ref u8 left, ref u8 right) {
	left = value >> 8;
	right = value & 0x00FF;
}

pure bool is_bit_set(immutable u8 value, immutable u8 mask) {
	return (value & mask) == mask;
}

pure void set_bit(ref u8 value, immutable u8 mask, immutable bool is_set) {
	if(is_set) {
		value |= mask;
	} else {
		value &= ~mask;
	}
}
