-- I'm pretty sure I got this file from Lapin https://github.com/ExtReMLapin
jit.util = jit.util or require("jit.util")

local disassemble_function

local OPNAMES = {}
local bcnames = require("jit.vmdef").bcnames
local INST = {}

do
	local i = 0

	for str in bcnames:gmatch"......" do
		str = str:gsub("%s", "")
		OPNAMES[i] = str
		INST[str] = i
		i = i + 1
	end
end

_G.OPNAMES = OPNAMES
_G.INST = INST

assert(INST.ISLT == 0)

local BCMode = {
	-- for the robots
	BCMnone = 0,
	BCMdst = 1,
	BCMbase = 2,
	BCMvar = 3,
	BCMrbase = 4,
	BCMuv = 5,
	BCMlit = 6,
	BCMlits = 7,
	BCMpri = 8,
	BCMnum = 9,
	BCMstr = 10,
	BCMtab = 11,
	BCMfunc = 12,
	BCMjump = 13,
	BCMcdata = 14,
	BCM_max = 15,
	-- for the human
	[0] = "BCMnone",
	[1] = "BCMdst",
	[2] = "BCMbase",
	[3] = "BCMvar",
	[4] = "BCMrbase",
	[5] = "BCMuv",
	[6] = "BCMlit",
	[7] = "BCMlits",
	[8] = "BCMpri",
	[9] = "BCMnum",
	[10] = "BCMstr",
	[11] = "BCMtab",
	[12] = "BCMfunc",
	[13] = "BCMjump",
	[14] = "BCMcdata",
	[15] = "BCM_max"
}

local jumps = {
	-- UCLO = true,
	ISNEXT = true,
	JMP = true,
	-- LOOP = true
}

local modes_actions = {
	A = {

	},
	B = {

	},
	C = {
		BCMlits = function(ins, n)
			if ins.D > 32767 then
				ins.D = ins.D - 65536
			end
		end,
		BCMnum = function(ins, n)
			if ins.OP == "TSETM" then
				local d = ins.proto.consts[ins.D]
				ins.D = d - 2 ^ 52
			end
		end,
		BCMfunc = function(ins, n)
			local proto = ins.proto
			local consts = proto.consts
			ins.D = disassemble_function(consts[-ins.D - 1])
			ins.D.parent = ins.proto
		end,
		BCMjump = function(ins, n)
			local pos = ins.D - 0x7fff + n
			ins.D = pos
			ins.proto.targets[pos] = true
			if jumps[ins.OP] then
				ins.OP = "JMP"
			end
		end,
	}
}

local do_mode_action = function(instruction, n)
	local fn
	fn = modes_actions.A[BCMode[instruction.CODE.A]]
	if fn then fn(instruction, n) end
	fn = modes_actions.B[BCMode[instruction.CODE.B]]
	if fn then fn(instruction, n) end
	fn = modes_actions.C[BCMode[instruction.CODE.C]]
	if fn then fn(instruction, n) end
end

disassemble_function = function(fn)
	assert(fn, "function expected")

	local fn_data = jit.util.funcinfo(fn)
	assert(fn_data.loc, "expected a Lua function, not a C one")

	local proto = {
		slots = fn_data.stackslots,
		params = fn_data.params,
		vararg = fn_data.isvararg,
		upvalues = {},
		consts = {},
		targets = {},
	}

	local upvalues = proto.upvalues
	for i = 0, fn_data.upvalues do
		upvalues[i] = jit.util.funcuvid(fn, i)
	end

	local consts = proto.consts
	do
		local n_consts = fn_data.nconsts
		local n = n_consts - 1

		local value = jit.util.funck(fn, n)
		while value ~= nil do
			consts[n] = value
			n = n - 1
			value = jit.util.funck(fn, n)
		end

		proto.consts = consts
	end

	-- instructions
	do
		local n_BC = fn_data.bytecodes
		local n = 1

		local instructions = {}
		while n < n_BC do
			local ins, mode = jit.util.funcbc(fn, n)
			local mode_a, mode_b, mode_c = bit.band(mode, 7), bit.rshift(bit.band(mode, 15 * 8),3),bit.rshift(bit.band(mode, 15 * 128),7)

			local instruction = {
				proto = proto,
				OP = OPNAMES[bit.band(ins, 0xff)],
				CODE = {
					A = mode_a,
					B = mode_b,
					C = mode_c
				},
				C = bit.rshift(bit.band(ins, 0x00ff0000), 16),
				B = bit.rshift(ins, 24),
				A = bit.rshift(bit.band(ins, 0x0000ff00), 8),
				D = bit.rshift(ins, 16),
			}

			do_mode_action(instruction, n)
			-- print(instruction.OP)

			instructions[n] = instruction
			n = n + 1
		end

		proto.instructions = instructions
	end

	return proto
end

return disassemble_function