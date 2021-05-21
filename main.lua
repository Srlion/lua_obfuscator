math.randomseed(tostring(function() end):sub(11))

package.path = ".\\?.lua"

local string = string
local sub, find, format = string.sub, string.find, string.format

local use_utf8

local conditionals = {
	"ISLT", "ISGE", "ISLE", "ISGT", "ISEQV", "ISNEV",
	"ISEQS", "ISNES", "ISEQN", "ISNEN", "ISEQP", "ISNEP",
	"ISTC", "ISFC", "IST", "ISF";
	"FORI"; "FORL", "ITERL"
}
for i = 1, #conditionals do
	local v = conditionals[i]
	conditionals[v], conditionals[i] = true, nil
end
local loops = {
	FORI = true,
	FORL = true,
	ITERL = true,
}
local returns = {
	RET = true,
	RET0 = true,
	RET1 = true,
	RETM = true,
	CALLMT = true,
	CALLT = true,
}

function table.Shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end

	return tbl
end

function string.tohex(str)
	str = str:gsub(".", function(c) return format("\\x%02X", c:byte()) end)
	return str
end

function string.Explode(separator, str, withpattern)
	if withpattern == nil then
		withpattern = false
	end
	local ret = {}
	local current_pos = 1
	for i = 1, #str do
		local start_pos, end_pos = find(str, separator, current_pos, not withpattern)
		if (not start_pos) then break end
		ret[i] = sub(str, current_pos, start_pos - 1)
		current_pos = end_pos + 1
	end
	ret[#ret + 1] = sub(str, current_pos)
	if ret[#ret] == "" then
		table.remove(ret)
	end
	return ret
end

------------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

local to_lua_num; do
	local hex_number = function(v)
		local neg = v < 0
		if neg then
			v = math.abs(v)
		end
		if math.floor(v) == v and v <= 0xffffffff then
			v = "0x" .. string.format("%x", v)
		end
		if neg then
			v = "-" .. v
		end
		return v
	end

	local prime_dactors = function(n, ret)
		ret = ret or {hex_number(1)}

		while (n % 2 == 0) do
			table.insert(ret, hex_number(2))
			n = n / 2
		end

		local i = 3
		while i <= math.sqrt(n) do
			while (n % i == 0) do
				table.insert(ret, hex_number(i))
				n = n / i
			end

			i = i + 2
		end

		if n > 2 then
			table.insert(ret, hex_number(n))
		end

		return table.concat(table.Shuffle(ret), "*")
	end

	to_lua_num = function(v)
		if v == 0 then
			return "(" .. prime_dactors(math.random(300, 400), {hex_number(0)}) .. ")"
		end

		if v < 0 then
			return "-(" .. prime_dactors(math.abs(v)) .. ")"
		end

		return "(" .. prime_dactors(v) .. ")"
	end
end

local get_pri = function(v)
	if v == 1 or v == false then
		return "!!!1"
	elseif v == 2 or v == true then
		return "!!1"
	elseif v == 0 then
		return "nil"
	end
	error("wtf")
end

local end_condition = false
local OPS; OPS = {
	ISLT = function(s, A, B, C, D)
		s:writef("if(%s<%s)then ", s:get_var(A), s:get_var(D))
	end,
	ISGE = function(s, A, B, C, D)
		s:writef("if(%s>=%s)then ", s:get_var(A), s:get_var(D))
	end,
	ISLE = function(s, A, B, C, D)
		s:writef("if(%s<=%s)then ", s:get_var(A), s:get_var(D))
	end,
	ISGT = function(s, A, B, C, D)
		s:writef("if(%s>%s)then ", s:get_var(A), s:get_var(D))
	end,
	ISEQV = function(s, A, B, C, D)
		s:writef("if(%s==%s)then ", s:get_var(A), s:get_var(D))
	end,
	ISNEV = function(s, A, B, C, D)
		s:writef("if(%s~=%s)then ", s:get_var(A), s:get_var(D))
	end,
	ISEQS = function(s, A, B, C, D)
		s:writef("if(%s==%s)then ", s:get_var(A), s:str(D))
	end,
	ISNES = function(s, A, B, C, D)
		s:writef("if(%s~=%s)then ", s:get_var(A), s:str(D))
	end,
	ISEQN = function(s, A, B, C, D)
		s:writef("if(%s==%s)then ", s:get_var(A), s:num(D))
	end,
	ISNEN = function(s, A, B, C, D)
		s:writef("if(%s~=%s)then ", s:get_var(A), s:num(D))
	end,
	ISEQP = function(s, A, B, C, D)
		s:writef("if(%s==%s)then ", s:get_var(A), get_pri(D))
	end,
	ISNEP = function(s, A, B, C, D)
		s:writef("if(%s~=%s)then ", s:get_var(A), get_pri(D))
	end,
	ISTC = function(s, A, B, C, D)
		D = s:get_var(D)
		s:writef([[if(%s)then ]], D)
		s:set_var(A, D)
	end,
	ISFC = function(s, A, B, C, D)
		D = s:get_var(D)
		s:writef([[if(!%s)then ]], D)
		s:set_var(A, D)
	end,
	IST = function(s, A, B, C, D)
		s:writef("if(%s)then ", s:get_var(D))
	end,
	ISF = function(s, A, B, C, D)
		s:writef("if(!%s)then ", s:get_var(D))
	end,
	MOV = function(s, A, B, C, D, ...)
		s:set_var(A, s:get_var(D))
	end,
	NOT = function(s, A, B, C, D)
		s:set_var(A, "!" .. s:get_var(D))
	end,
	UNM = function(s, A, B, C, D)
		s:set_var(A, "-" .. s:get_var(D))
	end,
	LEN = function(s, A, B, C, D)
		s:set_var(A, "#" .. s:get_var(D))
	end,
	ADDVN = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "+" .. s:num(C))
	end,
	SUBVN = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "-" .. s:num(C))
	end,
	MULVN = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "*" .. s:num(C))
	end,
	DIVVN = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "/" .. s:num(C))
	end,
	MODVN = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "%" .. s:num(C))
	end,
	ADDNV = function(s, A, B, C, D)
		s:set_var(A, s:num(C) .. "+" .. s:get_var(B))
	end,
	SUBNV = function(s, A, B, C, D)
		s:set_var(A, s:num(C) .. "-" .. s:get_var(B))
	end,
	MULNV = function(s, A, B, C, D)
		s:set_var(A, s:num(C) .. "*" .. s:get_var(B))
	end,
	DIVNV = function(s, A, B, C, D)
		s:set_var(A, s:num(C) .. "/" .. s:get_var(B))
	end,
	MODNV = function(s, A, B, C, D)
		s:set_var(A, s:num(C) .. "%" .. s:get_var(B))
	end,
	ADDVV = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "+" .. s:get_var(C))
	end,
	SUBVV = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "-" .. s:get_var(C))
	end,
	MULVV = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "*" .. s:get_var(C))
	end,
	DIVVV = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "/" .. s:get_var(C))
	end,
	MODVV = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "%" .. s:get_var(C))
	end,
	POW = function(s, A, B, C, D)
		s:set_var(A, s:get_var(B) .. "^" .. s:get_var(C))
	end,
	CAT = function(s, A, B, C, D)
		local cat_tbl = {}
		for i = B, C do
			table.insert(cat_tbl, s:get_var(i))
		end
		s:set_var(A, table.concat(cat_tbl, ".."))
	end,
	KSTR = function(s, A, B, C, D)
		s:set_var(A, s:str(D))
	end,
	KSHORT = function(s, A, B, C, D)
		s:set_var(A, to_lua_num(D))
	end,
	KNUM = function(s, A, B, C, D)
		s:set_var(A, s:num(D))
	end,
	KPRI = function(s, A, B, C, D)
		s:set_var(A, get_pri(D))
	end,
	KNIL = function(s, A, B, C, D)
		for i = A, D do
			s:set_var(i, "nil")
		end
	end,
	UGET = function(s, A, B, C, D)
		s:set_var(A, s:get_uv(D))
	end,
	USETV = function(s, A, B, C, D)
		s:set_uv(A, s:get_var(D))
	end,
	USETS = function(s, A, B, C, D)
		s:set_uv(A, s:str(D))
	end,
	USETN = function(s, A, B, C, D)
		s:set_uv(A, s:num(D))
	end,
	USETP = function(s, A, B, C, D)
		s:set_uv(A, get_pri(D))
	end,
	UCLO = function(s, A, B, C, D, op, pc)
		OPS["JMP"](s, A, B, C, D, op, pc)
		if returns[s.proto.instructions[pc + 1].OP] then return end

		local slots = s.proto.slots
		for i = A, slots do
			if s.vars[i] and not s:get_uv(i) then
				s.mangled_vars[i] = i + slots + 1
			end
		end
	end,
	FNEW = function(s, A, B, C, D)
		local p = Parser.new(D, s)
		local body = "function(%s)%send"
		local params = {}
		for i = 0, D.params - 1 do
			p.vars[i] = 0
			table.insert(params, p:get_var(i))
		end
		if D.vararg then
			table.insert(params, "...")
		end
		body = body:format(table.concat(params, ","), p:loop())
		s.last_fnew = s:set_var(A, body)
	end,
	TNEW = function(s, A, B, C, D)
		s.table_values = {}
		s.last_array = {}
		s.table_pos = s:set_var(A, "{}")
		s.last_table_set = s.table_pos
	end,
	TDUP = function(s, A, B, C, D)
		D = s:const(D)

		s.table_values = {}
		local t = {}
		local _array = {}
		for i = 1, #D do
			_array[i] = true
			t[i] = s:get_value(D[i], true)
			D[i] = nil
		end
		for k, v in pairs(D) do
			table.insert(t, "[" .. s:get_value(k) .. "]=" .. s:get_value(v))
		end
		table.insert(t, "")
		s.last_array = _array
		s.table_pos = s:set_var(A, "{" .. table.concat(t, ";") .. "}")
		s.last_table_set = s.table_pos
	end,
	GGET = function(s, A, B, C, D)
		s:set_var(A, s:str(D, true))
	end,
	GSET = function(s, A, B, C, D)
		s:writef("%s=%s;", s:str(D, true), s:get_var(A))
	end,
	TGETV = function(s, A, B, C, D)
		s:set_var(A, format("%s[%s]", s:get_var(B), s:get_var(C)))
	end,
	TGETS = function(s, A, B, C, D)
		s:set_var(A, format("%s[%s]", s:get_var(B), s:str(C)))
	end,
	TGETB = function(s, A, B, C, D)
		s:set_var(A, format("%s[%s]", s:get_var(B), to_lua_num(C)))
	end,
	TSETV = function(s, A, B, C, D)
		local i = s:writef("%s[%s] = %s;", s:get_var(B), s:get_var(C), s:get_var(A))
		table.insert(s.table_values, {s:get_var(B), s:get_var(C), s:get_var(A), i})
		s.last_table_set = i
	end,
	TSETS = function(s, A, B, C, D)
		local i = s:writef("%s[%s] = %s;", s:get_var(B), s:str(C), s:get_var(A))
		s.last_table_set = i
	end,
	TSETB = function(s, A, B, C, D)
		local i = s:writef("%s[%s] = %s;", s:get_var(B), to_lua_num(C), s:get_var(A))
		table.insert(s.table_values, {s:get_var(B), to_lua_num(C), s:get_var(A), i, true})
		s.last_table_set = i
	end,
	TSETM = function(s, A, B, C, D)
		-- problems:
		--[[
			local s = {[2] = 3, math.abs(1)}
			will output
				{
					[1] = 1
				}
			instead of
				{
					[1] = 1,
					[2] = 3
				}
			thats because i don't know the size of function returns
			and if im going to fix it, it will be a lot more inefficient
		]]
		local output = s.output
		local last_op = s.last_op
		local last_call
		if last_op ~= "VARG" then
			last_call = output[#output]
			output[#output] = ""
			local str = ""
			for i = s.last_table_set + 1, #output - 1 do
				str = str .. output[i]
				output[i] = ""
			end
			output[s.table_pos] = str .. output[s.table_pos]
		end

		local table_values = s.table_values
		local table_output = output[s.table_pos]:sub(1, -3)

		for i = 1, D - 1 do
			if not s.last_array[i] then
				table_output = table_output .. "nil;"
			end
		end

		do
			local ex = (";"):Explode(table_output:sub(table_output:find("{") + 1), false)

			for i = D, math.huge do
				if not ex[i] then break end
				ex[i] = ""
			end

			::rep::
			for i = 1, #ex do
				if ex[i] == "" then
					table.remove(ex, i)
					goto rep
				end
			end
			table.insert(ex, "")
			table_output = table_output:sub(1, table_output:find("{")) .. table.concat(ex, ";")
		end

		for i = 1, #table_values do
			local v = table_values[i]
			local str
			if v[5] then
				if tonumber((v[2]:gsub("%W", ""))) >= D then
					str = ""
				else
					str = format([[%s[%s]=%s;]], v[1], v[2], v[3])
				end
			else
				str = format([[
					if tonumber(%s)&& %s+0>=%s then
					else
						%s[%s]=%s;end
				]], v[2], v[2], D, v[1], v[2], v[3])
			end
			output[v[4]] = str:gsub("\n", " ")
		end

		if last_op == "VARG" then
			table_output = table_output .. "...;};"
		else
			output[#output] = ""
			table_output = table_output .. last_call:sub(1, -2) .. ";};"
		end

		-- s:write(table_output)
		output[s.table_pos] = table_output
	end,
	CALLM = function(s, A, B, C, D)
		local last_op = s.last_op
		local last_call
		if last_op ~= "VARG" then
			last_call = s.output[s.last_call]
			s.output[s.last_call] = ""
		end

		local amt = (B or 1) - 1
		local MULTRES = amt == -1
		if not MULTRES then
			local st, en = A, A + amt - 1
			for i = st, en do
				s:set_var(i)
				if i < en then
					s:write(",")
				else
					s:write("=")
				end
			end
		end

		local str = s:get_var(A) .. "("
		local t = {}
		for i = A + 1, A + C do
			table.insert(t, s:get_var(i))
		end
		if last_op == "VARG" then
			table.insert(t, "...);")
		else
			table.insert(t, last_call:sub(1, -2) .. ");")
		end
		s.last_call = s:write(str .. table.concat(t, ","))
	end,
	CALL = function(s, A, B, C, D)
		local amt = (B or 1) - 1
		local MULTRES = amt == -1
		if not MULTRES then
			local st, en = A, A + amt - 1
			for i = st, en do
				s:set_var(i)
				if i < en then
					s:write(",")
				else
					s:write("=")
				end
			end
		end

		local str = s:get_var(A) .. "("
		local t = {}
		for i = A + 1, A + C - 1 do
			table.insert(t, s:get_var(i))
		end
		s.last_call = s:write(str .. table.concat(t, ",") .. ");")
	end,
	CALLMT = function(s, ...)
		s:write("do return ")
		OPS["CALLM"](s, ...)
		s:write("end;")
	end,
	CALLT = function(s, ...)
		s:write("do return ")
		OPS["CALL"](s, ...)
		s:write("end;")
	end,
	ITERC = function(s, A, B, C, D)
		s:set_var(A, s:get_var(A - 3))
		s:set_var(A + 1, s:get_var(A - 2))
		s:set_var(A + 2, s:get_var(A - 1))

		local st, en = A, A + B - 2
		for i = st, en do
			s:set_var(i)
			if i < en then
				s:write(",")
			else
				s:write("=")
			end
		end

		s:writef([[%s(%s,%s);]], s:get_var(A), s:get_var(A + 1), s:get_var(A + 2))
	end,
	RETM = function(s, A, B, C, D)
		local last_op = s.last_op
		local last_call
		if last_op ~= "VARG" then
			last_call = s.output[s.last_call]
			s.output[s.last_call] = ""
		end
		s:write("do return ")

		local rets = {}
		for i = A, A + D - 1 do
			table.insert(rets, s:get_var(i))
		end
		if last_op == "VARG" then
			table.insert(rets, "...")
		else
			table.insert(rets, last_call:sub(1, -2))
		end
		s:write(table.concat(rets, ","))
		s:write("end;")
	end,
	RET = function(s, A, B, C, D)
		s:write("do return ")
		local rets = {}
		for i = A, A + D - 2 do
			table.insert(rets, s:get_var(i))
		end
		s:write(table.concat(rets, ","))
		s:write(";")
		s:write("end;")
	end,
	RET0 = function(s)
		s:write("do return;end;")
	end,
	RET1 = function(s, A, B, C, D)
		s:writef("do return %s;end;", s:get_var(A))
	end,
	FORI = function(s, A, B, C, D)
		local start = s:get_var(A)
		local stop = s:get_var(A + 1)
		local step = s:get_var(A + 2)

		local i_iter = A + 3
		s:set_var(i_iter, start)

		s:writef([[if(!(%s<=0)&& !(%s<=%s))||(!(%s>=0)&& !(%s>=%s))then ]], step, s:get_var(i_iter), stop, step, s:get_var(i_iter), stop, s:get_var(D))
	end,
	FORL = function(s, A, B, C, D)
		local stop = s:get_var(A + 1)
		local step = s:get_var(A + 2)

		local i_iter = A + 3
		s:set_var(i_iter, s:get_var(i_iter) .. "+" .. step)

		s:writef([[if(!(%s<=0)&& !(%s>%s))||(!(%s>=0)&& !(%s<%s))then ]], step, s:get_var(i_iter), stop, step, s:get_var(i_iter), stop, s:get_var(D))
	end,
	ITERL = function(s, A, B, C, D)
		s:writef([[if(%s)then ]], s:get_var(A))
		s:set_var(A - 1, s:get_var(A))
	end,
	VARG = function(s, A, B, C, D)
		local amt = B - 1
		if amt == -1 then
			return
		end
		local t = {}
		for i = A, A + amt - 1 do
			table.insert(t, s:get_var(i))
		end
		if #t > 0 then
			s:writef("local %s=...", table.concat(t, ","))
		end
	end,
	JMP = function(s, A, B, C, D, op, pc)
		if pc + 1 == D and s.proto.targets[pc + 1] and not s.used_targets[D] then
			s.skip_target = true
		elseif not returns[s.last_op] then
			s:write("goto ")
			s:write(s:get_var(D))
			s:write(";")
			s.used_targets[D] = true
		end

		if end_condition then
			s:write("end;")
			end_condition = false

			s:end_scope()
			s:start_scope("do ")
		end
	end,
	LOOP = function()
	end
}
OPS.ITERN = OPS.ITERC

function Parser:write(v)
	local n = #self.output + 1
	self.output[n] = v
	return n
end

function Parser:writef(v, ...)
	return self:write(format(v, ...))
end

function Parser:start_scope(v)
	self.scope = self.scope + 1
	self:write(v)
end

function Parser:end_scope(v)
	if self.scope == 0 then return end
	self.scope = self.scope - 1
	self:write("end;")
end

local emojis = {
	"˝",
	"ˢ",
	"ˏ",
	"˛",
	"˵",
	"૰",
	"೭"
}
local random = function()
	math.randomseed(tostring(function() end):sub(11))
	return emojis[math.random(1, #emojis)]
end
function Parser:get_var(k)
	k = self.mangled_vars[k] or k

	if not use_utf8 then
		return "var" .. self.id .. k
	end

	local id = self.id .. k
	if type(k) == "number" then
		local en = k + 1
		k = ""
		for i = 1, en do
			k = k .. random()
		end
	else
		error("Wtf")
	end

	local name = self.var_names[id]
	if not name then
		name = string.rep("​", self.id) .. k
		self.var_names[id] = name
	end

	return name
end

function Parser:set_var(k, v)
	k = self.mangled_vars[k] or k

	if not self.vars[k] then
		self.vars[k] = true
	end

	local str = self:get_var(k)

	if v then
		str = str .. "=" .. tostring(v) .. ";"
	end

	return self:write(str)
end

function Parser:get_uv(uv)
	local i = self.proto.upvalues[uv]
	if not i then return end
	while i < 32768 do
		self = self.parent
		i = self.proto.upvalues[i]
	end
	return self.parent:get_var(i % 16384)
end

function Parser:set_uv(uv, v)
	self:write(self:get_uv(uv))
	self:write("=")
	self:write(v .. ";")
end

function Parser:const(i)
	local consts = self.proto.consts
	return consts[-i - 1]
end

function Parser:new_str(v)
	v = tostring(v)
	v = v:tohex()
	return "'" .. v .. "'"
end

function Parser:str(i, no_mangle)
	return no_mangle and self:const(i) or self:new_str(self:const(i))
end

function Parser:num(i)
	return to_lua_num(self.proto.consts[i])
end

function Parser:get_value(v, allow_nil)
	local t = type(v)
	if t == "string" then
		return self:new_str(v)
	elseif t == "boolean" then
		return get_pri(v)
	elseif t == "number" then
		return to_lua_num(v)
	elseif allow_nil and v == nil then
		return "nil"
	end
	error("wtfff")
end

do
	local proto_i = 1

	function Parser:loop()
		local proto = self.proto
		local instructions = proto.instructions
		local targets = proto.targets
		for pc = 1, #instructions do
			local ins = instructions[pc]
			local target = targets[pc]
			local op = ins.OP
			if target then
				self:end_scope()

				if self.skip_target then
					self.skip_target = nil
				else
					self:write("::")
					self:write(self:get_var(pc))
					self:write("::")
				end

				self:start_scope("do ")
			end

			OPS[op](self, ins.A, ins.B, ins.C, ins.D, op, pc)

			if conditionals[op] then
				end_condition = true
			end

			if loops[op] then
				OPS["JMP"](self, ins.A, ins.B, ins.C, ins.D, op, pc)
			end

			if op ~= "UCLO" then
				self.last_op = op
			end
		end

		for i = 1, self.scope do
			self:end_scope()
		end

		proto_i = proto_i - 1

		local vars = {}
		for k, v in pairs(self.vars) do
			if v ~= 0 then
				table.insert(vars, math.random(1, #vars + 1), self:get_var(k))
			end
		end

		if #vars > 0 then
			table.insert(self.output, 1, "local " .. table.concat(vars, ",") .. ";")
		end

		return table.concat(self.output):gsub("%s+", " ")
	end

	function Parser.new(proto, parent)
		proto_i = proto_i + 1
		return setmetatable({
			proto = proto,
			id = proto_i - 1,
			output = {},
			vars = {},
			parent = parent,
			scope = 0,
			table_values = {},
			used_targets = {},
			add_to_vars = 0,
			mangled_vars = {},
			var_names = {}
		}, Parser)
	end
end

local open = io.open
local write_file = function(path, content)
	local f = open(path, "wb")
	if not f then
		error(("File '%s' couldn't be created!"):format(path))
	end
	f:write(content)
	f:close()
end

local file_exists = function(name)
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

local inputs = {...}
local input_file = inputs[1]

if not input_file or not file_exists(input_file) then
	error("Invalid file to obfuscate!")
end

local output_file = inputs[2]
if type(output_file) ~= "string" then
	error("output file needs to be a string!")
end

use_utf8 = inputs[3] == "USE_UTF8"

os.execute("gluac\\gluac.exe -s " .. input_file)

local bc = loadfile("bc.lua")
local dis = require("libs/dis_bc")
local proto = dis(bc)
write_file(output_file, Parser.new(proto):loop())