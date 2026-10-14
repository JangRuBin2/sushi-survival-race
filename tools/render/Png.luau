--!strict
--!native
-- PNG 쓰기 (m5-23): 8비트 RGB, 줄마다 필터 0, zlib 압축은 @lune/serde, CRC32는 여기서 계산해요.
--   Png.encode(width, height, rgb: buffer) -> string

local serde = require("@lune/serde")

local Png = {}

local crcTable: { number } = {}
for n = 0, 255 do
	local c = n
	for _ = 1, 8 do
		if bit32.band(c, 1) == 1 then
			c = bit32.bxor(0xEDB88320, bit32.rshift(c, 1))
		else
			c = bit32.rshift(c, 1)
		end
	end
	crcTable[n + 1] = c
end

local function crc32(s: string): number
	local c = 0xFFFFFFFF
	local b = buffer.fromstring(s)
	for i = 0, buffer.len(b) - 1 do
		local byte = buffer.readu8(b, i)
		c = bit32.bxor(crcTable[bit32.band(bit32.bxor(c, byte), 0xFF) + 1], bit32.rshift(c, 8))
	end
	return bit32.bxor(c, 0xFFFFFFFF)
end

local function u32(n: number): string
	return string.pack(">I4", n)
end

local function chunk(kind: string, data: string): string
	return u32(#data) .. kind .. data .. u32(crc32(kind .. data))
end

function Png.encode(width: number, height: number, rgb: buffer): string
	local stride = width * 3
	local raw = buffer.create((stride + 1) * height)
	for y = 0, height - 1 do
		buffer.writeu8(raw, y * (stride + 1), 0)
		buffer.copy(raw, y * (stride + 1) + 1, rgb, y * stride, stride)
	end
	local compressed = serde.compress("zlib", buffer.tostring(raw))
	local header = u32(width) .. u32(height) .. string.char(8, 2, 0, 0, 0)
	return "\137PNG\r\n\26\n" .. chunk("IHDR", header) .. chunk("IDAT", compressed) .. chunk("IEND", "")
end

-- PNG 읽기 (m5-32, 사용자 시트를 렌더 옆에 붙이려고): 8비트 RGB·RGBA, 비월 없음, 필터 0~4. 알파는 흰 바탕에 섞어요.
--   Png.decode(bytes) -> (width, height, rgb: buffer)
local function paeth(a: number, b: number, c: number): number
	local p = a + b - c
	local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
	if pa <= pb and pa <= pc then
		return a
	elseif pb <= pc then
		return b
	end
	return c
end

function Png.decode(bytes: string): (number, number, buffer)
	assert(string.sub(bytes, 1, 8) == "\137PNG\r\n\26\n", "not a PNG")
	local pos = 9
	local width, height, colorType = 0, 0, 0
	local idat: { string } = {}
	while pos <= #bytes do
		local length = string.unpack(">I4", bytes, pos)
		local kind = string.sub(bytes, pos + 4, pos + 7)
		local data = string.sub(bytes, pos + 8, pos + 7 + length)
		if kind == "IHDR" then
			local depth, interlace
			width, height, depth, colorType = string.unpack(">I4I4BB", data)
			interlace = string.byte(data, 13)
			assert(depth == 8 and (colorType == 2 or colorType == 6) and interlace == 0, "only 8-bit RGB/RGBA PNG")
		elseif kind == "IDAT" then
			table.insert(idat, data)
		elseif kind == "IEND" then
			break
		end
		pos += 12 + length
	end
	local channels = if colorType == 6 then 4 else 3
	local raw = buffer.fromstring(serde.decompress("zlib", table.concat(idat)))
	local stride = width * channels
	local cur = buffer.create(stride)
	local prev = buffer.create(stride)
	local out = buffer.create(width * height * 3)
	for y = 0, height - 1 do
		local base = y * (stride + 1)
		local filter = buffer.readu8(raw, base)
		for i = 0, stride - 1 do
			local x = buffer.readu8(raw, base + 1 + i)
			local a = if i >= channels then buffer.readu8(cur, i - channels) else 0
			local b = buffer.readu8(prev, i)
			local c = if i >= channels then buffer.readu8(prev, i - channels) else 0
			local v = x
			if filter == 1 then
				v = x + a
			elseif filter == 2 then
				v = x + b
			elseif filter == 3 then
				v = x + math.floor((a + b) / 2)
			elseif filter == 4 then
				v = x + paeth(a, b, c)
			end
			buffer.writeu8(cur, i, v % 256)
		end
		for px = 0, width - 1 do
			local o = px * channels
			local alpha = if channels == 4 then buffer.readu8(cur, o + 3) / 255 else 1
			for ch = 0, 2 do
				local value = buffer.readu8(cur, o + ch) * alpha + 255 * (1 - alpha)
				buffer.writeu8(out, (y * width + px) * 3 + ch, math.floor(value + 0.5))
			end
		end
		prev, cur = cur, prev
	end
	return width, height, out
end

return Png
