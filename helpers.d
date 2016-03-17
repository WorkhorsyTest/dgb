
module helpers;

import types;

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
