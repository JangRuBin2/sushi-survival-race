--!strict
-- m5-25 캐릭터 미리보기 렌더러의 순수 도우미: Sheet(격자·글자·축소), LayoutCheck(z-fighting·떠 있는 파츠)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local LayoutCheck = require("../tools/render/LayoutCheck")
local Sheet = require("../tools/render/Sheet")

local Shared = RobloxRequire.root("src/shared")
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Skins = RobloxRequire.require(Shared.Skins)

local function pixel(image: Sheet.Image, x: number, y: number): { number }
	local o = (y * image.width + x) * 3
	return { buffer.readu8(image.rgb, o), buffer.readu8(image.rgb, o + 1), buffer.readu8(image.rgb, o + 2) }
end

local function block(name: string, size: { number }, offset: { number }, extra: { [string]: any }?): any
	local spec: { [string]: any } = { name = name, size = size, offset = offset }
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end

return function(t: Test.Test)
	t.test("Sheet.grid: 칸 수보다 열이 많지 않고 행은 올림", function()
		t.eq({ Sheet.grid(31, 8) }, { 8, 4 })
		t.eq({ Sheet.grid(3, 8) }, { 3, 1 })
		t.eq({ Sheet.grid(16, 8) }, { 8, 2 })
		t.eq({ Sheet.grid(0, 8) }, { 1, 1 })
	end)

	t.test("Sheet.cellOrigin: 행 우선, 여백 포함", function()
		t.eq({ Sheet.cellOrigin(1, 4, 100, 50, 5) }, { 5, 5 })
		t.eq({ Sheet.cellOrigin(4, 4, 100, 50, 5) }, { 5 + 3 * 105, 5 })
		t.eq({ Sheet.cellOrigin(5, 4, 100, 50, 5) }, { 5, 5 + 55 })
	end)

	t.test("Sheet.new·blit: 채우기와 잘라 붙이기", function()
		local dst = Sheet.new(4, 3, { 10, 20, 30 })
		t.eq(pixel(dst, 3, 2), { 10, 20, 30 })
		local src = Sheet.new(2, 2, { 200, 100, 50 })
		Sheet.blit(dst, src, 3, -1) -- 오른쪽 위로 넘쳐요
		t.eq(pixel(dst, 3, 0), { 200, 100, 50 })
		t.eq(pixel(dst, 2, 0), { 10, 20, 30 })
		t.eq(pixel(dst, 3, 1), { 10, 20, 30 })
		Sheet.blit(dst, src, 10, 10) -- 완전히 밖: 아무 일 없음
		t.eq(pixel(dst, 0, 0), { 10, 20, 30 })
	end)

	t.test("Sheet.text: 5×7 글꼴, 폭 = (글자 수 × 6 - 1) × 배율, 소문자는 대문자", function()
		t.eq(Sheet.textWidth("", 2), 0)
		t.eq(Sheet.textWidth("AB", 1), 11)
		t.eq(Sheet.textWidth("tamago", 2), 70)
		for ch, glyph in Sheet.GLYPHS do
			t.eq(#glyph, 7, `glyph {ch} rows`)
			for _, row in glyph do
				t.eq(#row, 5, `glyph {ch} width`)
			end
		end
		local image = Sheet.new(12, 8)
		Sheet.text(image, 0, 0, "i", 1, { 255, 255, 255 })
		-- I의 맨 윗줄은 "#####"
		t.eq(pixel(image, 0, 0), { 255, 255, 255 })
		t.eq(pixel(image, 4, 0), { 255, 255, 255 })
		t.eq(pixel(image, 5, 0), { 0, 0, 0 })
		t.eq(pixel(image, 0, 3), { 0, 0, 0 })
	end)

	t.test("Sheet.downscale: 평균", function()
		local src = Sheet.new(2, 2)
		Sheet.fill(src, 0, 0, 1, 2, { 200, 0, 100 })
		local out = Sheet.downscale(src, 2)
		t.eq({ out.width, out.height }, { 1, 1 })
		t.eq(pixel(out, 0, 0), { 100, 0, 50 })
	end)

	t.test("LayoutCheck.zFight: 같은 쪽 면이 같은 평면에서 겹치면 찾아요", function()
		-- 위 면이 y = 1에서 겹치는 두 상자
		local found = LayoutCheck.zFight({
			block("A", { 2, 2, 2 }, { 0, 0, 0 }),
			block("B", { 1, 1, 1 }, { 0.2, 0.5, 0 }),
		})
		t.eq(found, { "A/B +Y" })
		-- 맞닿기만 하는 면(서로 반대쪽)은 아니에요
		t.eq(LayoutCheck.zFight({ block("A", { 2, 2, 2 }, { 0, 0, 0 }), block("B", { 2, 2, 2 }, { 0, 2, 0 }) }), {})
		-- 회전·공·투명 파츠는 건너뛰어요
		t.eq(
			LayoutCheck.zFight({
				block("A", { 2, 2, 2 }, { 0, 0, 0 }),
				block("B", { 1, 1, 1 }, { 0, 0.5, 0 }, { rotation = { 0, 30, 0 } }),
				block("C", { 1, 1, 1 }, { 0, 0.5, 0 }, { shape = "Ball" }),
				block("D", { 1, 1, 1 }, { 0, 0.5, 0 }, { transparency = 1 }),
			}),
			{}
		)
	end)

	t.test("LayoutCheck.floating: 아무 데도 닿지 않는 파츠", function()
		local layout = {
			block("Body", { 2, 2, 2 }, { 0, 0, 0 }),
			block("Hat", { 1, 0.5, 1 }, { 0, 1.25, 0 }), -- 위에 딱 붙음
			block("Spike", { 0.2, 0.2, 0.2 }, { 0, 1.7, 0 }), -- Hat 위 0.1 떠 있음 (Hat 꼭대기 1.5, Spike 바닥 1.6)
		}
		t.eq(LayoutCheck.floating(layout), { "Spike" })
		t.eq(LayoutCheck.floating(layout, 0.2), {})
	end)

	t.test("LayoutCheck.box는 SushiBody.bounds와 같은 외곽 (모든 스킨의 모든 파츠)", function()
		for _, skin in Skins.LIST do
			for _, spec in SushiBody.layout(skin.id) do
				local lo, hi = LayoutCheck.box(spec)
				local b = SushiBody.bounds({ spec })
				for axis = 1, 3 do
					t.ok(math.abs(lo[axis] - b.min[axis]) < 1e-9, `{skin.id}.{spec.name} min {axis}`)
					t.ok(math.abs(hi[axis] - b.max[axis]) < 1e-9, `{skin.id}.{spec.name} max {axis}`)
				end
			end
		end
	end)
end
