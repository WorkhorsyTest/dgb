


module types;

import std.conv;
import std.stdint;

alias int8_t    s8;
alias int16_t   s16;
alias int32_t   s32;
alias int64_t   s64;

alias uint8_t   u8;
alias uint16_t  u16;
alias uint32_t  u32;
alias uint64_t  u64;

// Make sure all the types are the expected sizes
static this() {
	assert(s8.sizeof == 1, "s8 should be 8 bits not " ~ to!string(s8.sizeof*8) ~ " bits.");
	assert(s16.sizeof == 2, "s16 should be 16 bits not " ~ to!string(s16.sizeof*8) ~ " bits.");
	assert(s32.sizeof == 4, "s32 should be 32 bits not " ~ to!string(s32.sizeof*8) ~ " bits.");
	assert(s64.sizeof == 8, "s64 should be 64 bits not " ~ to!string(s64.sizeof*8) ~ " bits.");

	assert(u8.sizeof == 1, "u8 should be 8 bits not " ~ to!string(u8.sizeof*8) ~ " bits.");
	assert(u16.sizeof == 2, "u16 should be 16 bits not " ~ to!string(u16.sizeof*8) ~ " bits.");
	assert(u32.sizeof == 4, "u32 should be 32 bits not " ~ to!string(u32.sizeof*8) ~ " bits.");
	assert(u64.sizeof == 8, "u64 should be 64 bits not " ~ to!string(u64.sizeof*8) ~ " bits.");
}

