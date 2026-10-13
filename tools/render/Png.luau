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

return Png
