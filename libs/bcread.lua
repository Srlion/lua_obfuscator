local strsub, strbyte = string.sub, string.byte
local bor, band, lshift, rshift = bit.bor, bit.band, bit.lshift, bit.rshift

local function byte(ls, p)
	p = p or ls.p
	return strbyte(ls.data, p, p)
end

local function bcread_consume(ls, len)
	for p = ls.p, ls.p + len - 1 do
		ls.bytes[#ls.bytes + 1] = byte(ls, p)
	end
	ls.n = ls.n - len
end

local function bcread_dec(ls)
	local b = byte(ls)
	ls.bytes[#ls.bytes + 1] = b
	ls.n = ls.n - 1
	return b
end

local function bcread_byte(ls)
	local b = bcread_dec(ls)
	ls.p = ls.p + 1
	return b
end

local function bcread_uint16(ls)
	local a, b = strbyte(ls.data, ls.p, ls.p + 1)
	bcread_consume(ls, 2)
	ls.p = ls.p + 2
	return bor(lshift(b, 8), a)
end

local function bcread_uleb128(ls)
	local v = bcread_byte(ls)
	if v >= 0x80 then
		local sh = 0
		v = band(v, 0x7f)
		repeat
			local b = bcread_byte(ls)
			v = bor(v, lshift(band(b, 0x7f), sh + 7))
			sh = sh + 7
		until b < 0x80
	end
	return v
end

local function bcread_uleb128_33(ls)
	local v = rshift(bcread_byte(ls), 1)
	if v >= 0x40 then
		local sh = -1
		v = band(v, 0x3f)
		repeat
			sh = sh + 7
			local b = bcread_byte(ls)
			v = bor(v, lshift(band(b, 0x7f), sh))
		until b < 0x80
	end
	return v
end

local function bcread_mem(ls, len)
	local s = strsub(ls.data, ls.p, ls.p + len - 1)
	bcread_consume(ls, len)
	ls.p = ls.p + len
	return s
end

local function bcread_ktabk(ls)
	local tp = bcread_uleb128(ls)
	if tp == 3 then
		bcread_uleb128(ls)
	elseif tp == 4 then
		bcread_uleb128(ls)
		bcread_uleb128(ls)
	elseif tp >= 5 then
		bcread_mem(ls, tp - 5)
	end
end

local function bcread_kgc(ls, target)
	local tp = bcread_uleb128(ls)
	if tp >= 5 then
		bcread_mem(ls, tp - 5)
	elseif tp == 1 then
		local narray = bcread_uleb128(ls)
		local nhash = bcread_uleb128(ls)

		for i = 1, narray do
			bcread_ktabk(ls)
		end

		for i = 1, nhash do
			bcread_ktabk(ls)
			bcread_ktabk(ls)
		end

		return narray - 1
	elseif tp == 0 then
		return table.remove(target.childs)
	else
		error("kgc type " .. tp)
	end
end

local function bcread_proto(ls, target)
	if ls.n > 0 and byte(ls) == 0 then
		bcread_byte(ls)
		return nil
	end

	local proto = {
		consts = {},
		upvalues = {},
	}
	target.proto = proto

	local len = bcread_uleb128(ls)
	local startn = ls.n

	bcread_byte(ls)
	bcread_byte(ls)
	bcread_byte(ls)

	local sizeuv = bcread_byte(ls)
	local sizekgc = bcread_uleb128(ls)
	local sizekn = bcread_uleb128(ls)
	local sizebc = bcread_uleb128(ls)

	local sizedbg = 0
	local not_stripped = band(ls.flags, 2) == 0
	if not_stripped then
		sizedbg = bcread_uleb128(ls)
		if sizedbg ~= 0 then
			bcread_uleb128(ls)
			bcread_uleb128(ls)
		end
	end

	for pc = 1, sizebc do
		bcread_mem(ls, 4)
	end

	for i = 1, sizeuv do
		proto.upvalues[i - 1] = bcread_uint16(ls)
	end

	for i = 1, sizekgc do
		proto.consts[-(sizekgc + 1) + i] = bcread_kgc(ls, target)
	end

	for i = 1, sizekn do
		local isnumbit = band(byte(ls), 1)
		bcread_uleb128_33(ls)
		if isnumbit ~= 0 then
			bcread_uleb128(ls)
		end
	end

	if not_stripped and sizedbg ~= 0 then
		bcread_mem(ls, sizedbg)
	end

	assert(len == startn - ls.n, "prototype bytecode size mismatch")
	return target.proto
end

local function bcread(s)
	local ls = {data = s, n = #s, p = 1, bytes = {}}
	local target = {
		childs = {}
	}

	-- header
	do
		bcread_mem(ls, 3)
		bcread_uleb128(ls)
		local flags = bcread_uleb128(ls)
		if (band(flags, 2) ~= 2) then
			bcread_mem(ls, bcread_uleb128(ls))
		end
		ls.flags = flags
	end

	repeat
		local pt = bcread_proto(ls, target)
		target.childs[#target.childs + 1] = pt
	until not pt

	return target.proto
end

return bcread