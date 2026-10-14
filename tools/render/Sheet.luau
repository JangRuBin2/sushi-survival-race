--!strict
-- 여러 렌더를 한 장으로 모으는 도구 (m5-25 캐릭터 렌더러). Roblox·Lune API 없이 buffer만 써요 (테스트 가능).
--   Sheet.new(width, height, rgb?) -> Image        rgb {r,g,b} 0~255로 채운 빈 그림
--   Sheet.blit(dst, src, x, y)                     src를 dst의 (x, y)에 복사 (넘치는 부분은 잘라요)
--   Sheet.fill(dst, x, y, w, h, rgb)               사각형 채우기
--   Sheet.grid(count, cols) -> (cols, rows)        칸 수에 맞는 격자 (cols는 count보다 크지 않게)
--   Sheet.cellOrigin(index, cols, cellW, cellH, pad) -> (x, y)   1부터 세는 칸의 왼쪽 위 (pad = 칸 사이·바깥 여백)
--   Sheet.textWidth(text, scale) -> number         5×7 픽셀 글꼴 폭 (글자 사이 1픽셀 × scale)
--   Sheet.text(dst, x, y, text, scale, rgb)        5×7 픽셀 글꼴로 글자 쓰기 (영문 대문자·숫자·- . / : ( ) % _ +, 소문자는 대문자로)
--   Sheet.downscale(src, factor) -> Image          factor×factor 평균으로 줄이기
-- Image = { width, height, rgb: buffer } (Png.encode와 같은 8비트 RGB, 줄 우선)

local Sheet = {}

export type Image = { width: number, height: number, rgb: buffer }

function Sheet.new(width: number, height: number, rgb: { number }?): Image
	local buf = buffer.create(width * height * 3)
	local c = rgb or { 0, 0, 0 }
	if c[1] ~= 0 or c[2] ~= 0 or c[3] ~= 0 then
		for i = 0, width * height - 1 do
			buffer.writeu8(buf, i * 3, c[1])
			buffer.writeu8(buf, i * 3 + 1, c[2])
			buffer.writeu8(buf, i * 3 + 2, c[3])
		end
	end
	return { width = width, height = height, rgb = buf }
end

function Sheet.blit(dst: Image, src: Image, x: number, y: number)
	local x0, x1 = math.max(0, x), math.min(dst.width, x + src.width)
	if x1 <= x0 then
		return
	end
	for sy = 0, src.height - 1 do
		local dy = y + sy
		if dy >= 0 and dy < dst.height then
			buffer.copy(dst.rgb, (dy * dst.width + x0) * 3, src.rgb, (sy * src.width + (x0 - x)) * 3, (x1 - x0) * 3)
		end
	end
end

function Sheet.fill(dst: Image, x: number, y: number, w: number, h: number, rgb: { number })
	for py = math.max(0, y), math.min(dst.height, y + h) - 1 do
		for px = math.max(0, x), math.min(dst.width, x + w) - 1 do
			local o = (py * dst.width + px) * 3
			buffer.writeu8(dst.rgb, o, rgb[1])
			buffer.writeu8(dst.rgb, o + 1, rgb[2])
			buffer.writeu8(dst.rgb, o + 2, rgb[3])
		end
	end
end

function Sheet.grid(count: number, cols: number): (number, number)
	local c = math.max(1, math.min(cols, count))
	return c, math.max(1, math.ceil(count / c))
end

function Sheet.cellOrigin(index: number, cols: number, cellW: number, cellH: number, pad: number): (number, number)
	local i = index - 1
	local col, row = i % cols, math.floor(i / cols)
	return pad + col * (cellW + pad), pad + row * (cellH + pad)
end

-- 5×7 글꼴: 글자마다 7줄, 줄마다 5칸 ("#" = 켜짐)
local GLYPHS: { [string]: { string } } = {
	A = { " ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #" },
	B = { "#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### " },
	C = { " ####", "#    ", "#    ", "#    ", "#    ", "#    ", " ####" },
	D = { "#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### " },
	E = { "#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####" },
	F = { "#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    " },
	G = { " ####", "#    ", "#    ", "#  ##", "#   #", "#   #", " ####" },
	H = { "#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #" },
	I = { "#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "#####" },
	J = { "  ###", "    #", "    #", "    #", "    #", "#   #", " ### " },
	K = { "#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #" },
	L = { "#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####" },
	M = { "#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #" },
	N = { "#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #" },
	O = { " ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### " },
	P = { "#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    " },
	Q = { " ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #" },
	R = { "#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #" },
	S = { " ####", "#    ", "#    ", " ### ", "    #", "    #", "#### " },
	T = { "#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  " },
	U = { "#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### " },
	V = { "#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  " },
	W = { "#   #", "#   #", "#   #", "# # #", "# # #", "## ##", "#   #" },
	X = { "#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #" },
	Y = { "#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  " },
	Z = { "#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####" },
	["0"] = { " ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### " },
	["1"] = { "  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### " },
	["2"] = { " ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####" },
	["3"] = { "#### ", "    #", "    #", " ### ", "    #", "    #", "#### " },
	["4"] = { "   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # " },
	["5"] = { "#####", "#    ", "#### ", "    #", "    #", "#   #", " ### " },
	["6"] = { " ### ", "#    ", "#    ", "#### ", "#   #", "#   #", " ### " },
	["7"] = { "#####", "    #", "   # ", "  #  ", "  #  ", "  #  ", "  #  " },
	["8"] = { " ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### " },
	["9"] = { " ### ", "#   #", "#   #", " ####", "    #", "    #", " ### " },
	["-"] = { "     ", "     ", "     ", " ### ", "     ", "     ", "     " },
	["_"] = { "     ", "     ", "     ", "     ", "     ", "     ", "#####" },
	["."] = { "     ", "     ", "     ", "     ", "     ", " ##  ", " ##  " },
	["/"] = { "    #", "    #", "   # ", "  #  ", " #   ", "#    ", "#    " },
	[":"] = { "     ", " ##  ", " ##  ", "     ", " ##  ", " ##  ", "     " },
	["("] = { "   # ", "  #  ", " #   ", " #   ", " #   ", "  #  ", "   # " },
	[")"] = { " #   ", "  #  ", "   # ", "   # ", "   # ", "  #  ", " #   " },
	["%"] = { "##  #", "##  #", "   # ", "  #  ", " #   ", "#  ##", "#  ##" },
	["+"] = { "     ", "  #  ", "  #  ", "#####", "  #  ", "  #  ", "     " },
	[" "] = { "     ", "     ", "     ", "     ", "     ", "     ", "     " },
}
Sheet.GLYPHS = GLYPHS
Sheet.GLYPH_W = 5
Sheet.GLYPH_H = 7

function Sheet.textWidth(text: string, scale: number): number
	local n = #text
	if n == 0 then
		return 0
	end
	return (n * 6 - 1) * scale
end

function Sheet.text(dst: Image, x: number, y: number, text: string, scale: number, rgb: { number })
	local cx = x
	for i = 1, #text do
		local ch = string.upper(string.sub(text, i, i))
		local glyph = GLYPHS[ch] or GLYPHS["_"]
		for gy = 1, 7 do
			local row = glyph[gy]
			for gx = 1, 5 do
				if string.sub(row, gx, gx) == "#" then
					Sheet.fill(dst, cx + (gx - 1) * scale, y + (gy - 1) * scale, scale, scale, rgb)
				end
			end
		end
		cx += 6 * scale
	end
end

function Sheet.downscale(src: Image, factor: number): Image
	local f = math.max(1, math.floor(factor))
	local w, h = math.floor(src.width / f), math.floor(src.height / f)
	local out = Sheet.new(w, h)
	local n = f * f
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local r, g, b = 0, 0, 0
			for sy = 0, f - 1 do
				for sx = 0, f - 1 do
					local o = ((y * f + sy) * src.width + x * f + sx) * 3
					r += buffer.readu8(src.rgb, o)
					g += buffer.readu8(src.rgb, o + 1)
					b += buffer.readu8(src.rgb, o + 2)
				end
			end
			local o = (y * w + x) * 3
			buffer.writeu8(out.rgb, o, math.floor(r / n + 0.5))
			buffer.writeu8(out.rgb, o + 1, math.floor(g / n + 0.5))
			buffer.writeu8(out.rgb, o + 2, math.floor(b / n + 0.5))
		end
	end
	return out
end

-- 잘라 내서 w×h로 맞추기 (가장 가까운 점 + 2×2 평균, m5-32 사용자 시트 붙이기)
--   Sheet.cropResize(src, x, y, cw, ch, w, h) -> Image
function Sheet.cropResize(src: Image, x: number, y: number, cw: number, ch: number, w: number, h: number): Image
	local out = Sheet.new(w, h)
	for py = 0, h - 1 do
		for px = 0, w - 1 do
			local sx = x + (px + 0.5) * cw / w
			local sy = y + (py + 0.5) * ch / h
			local r, g, b = 0, 0, 0
			for _, d in { { -0.25, -0.25 }, { 0.25, -0.25 }, { -0.25, 0.25 }, { 0.25, 0.25 } } do
				local ix = math.clamp(math.floor(sx + d[1] * cw / w), 0, src.width - 1)
				local iy = math.clamp(math.floor(sy + d[2] * ch / h), 0, src.height - 1)
				local o = (iy * src.width + ix) * 3
				r += buffer.readu8(src.rgb, o)
				g += buffer.readu8(src.rgb, o + 1)
				b += buffer.readu8(src.rgb, o + 2)
			end
			local o = (py * w + px) * 3
			buffer.writeu8(out.rgb, o, math.floor(r / 4 + 0.5))
			buffer.writeu8(out.rgb, o + 1, math.floor(g / 4 + 0.5))
			buffer.writeu8(out.rgb, o + 2, math.floor(b / 4 + 0.5))
		end
	end
	return out
end

return Sheet
