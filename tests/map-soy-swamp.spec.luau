--!strict
-- m2-02 "간장 늪 & 와사비 산": 코스 치수 약속(스펙 범위)과 장애물 판정 순수 계산

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local Layout = RobloxRequire.require(Shared.maps.SoySwampLayout)

local GRAVITY = 196.2 -- Roblox 기본 Workspace.Gravity

local function edges(box: { x: number, z: number, width: number, depth: number })
	return box.x - box.width / 2, box.x + box.width / 2, box.z + box.depth / 2, box.z - box.depth / 2
end

return function(t: Test.Test)
	t.test("SoySwamp: 풀에 등록된 Race 맵이고 이름·규칙이 m2-01 표와 같아요 (AC1)", function()
		local map = Maps.get("soy-swamp")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Race")
		t.eq(map.displayName, "간장 늪 & 와사비 산")
		t.eq(map.rule, "간장 웅덩이는 피하고, 와사비 패드로 튀어 올라 결승선까지!")
	end)

	t.test(
		"코스: 구간이 출발→늪→산→내리막→결승 순서로 빈틈없이 이어지고 길이 150~190",
		function()
			local order = { Layout.START, Layout.SWAMP, Layout.APPROACH, Layout.MOUNTAIN, Layout.SLOPE, Layout.FINISH }
			t.eq(order[1].front, 0)
			for i, span in order do
				t.ok(span.front > span.back, `section {i} must extend toward -Z`)
				if i > 1 then
					t.eq(span.front, order[i - 1].back, `section {i} must start where {i - 1} ends`)
				end
			end
			local length = Layout.totalLength()
			t.ok(length >= 150 and length <= 190, `length {length}`)
			t.ok(Layout.WIDTH >= 20, "swamp floor must be at least 20 wide")
		end
	)

	t.test("스폰: 24개, 출발 구간 안, 겹치지 않아요", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
		local seen = {}
		for _, pos in spawns do
			t.ok(math.abs(pos.x) + 1.5 <= Layout.WIDTH / 2, `spawn x {pos.x} outside course`)
			t.ok(pos.z < Layout.START.front - 1 and pos.z > Layout.START.back + 1, `spawn z {pos.z} outside start`)
			local key = `{pos.x},{pos.z}`
			t.ok(not seen[key], `duplicate spawn {key}`)
			seen[key] = true
		end
	end)

	t.test(
		"간장 늪: 웅덩이는 늪 안에 있고, 줄마다 폭 3~4의 마른 길이 번갈아 남아요",
		function()
			t.ok(#Layout.PUDDLES >= 2, "several puddles")
			local half = Layout.WIDTH / 2
			local lastGapSide = 0
			for i, box in Layout.PUDDLES do
				local left, right, front, back = edges(box)
				t.ok(front <= Layout.SWAMP.front and back >= Layout.SWAMP.back, `puddle {i} outside swamp`)
				t.ok(left >= -half and right <= half, `puddle {i} outside walls`)
				local gapLeft, gapRight = left + half, half - right
				-- 한쪽만 비고 그 폭이 마른 길 폭이에요
				local gap, side = gapRight, 1
				if gapLeft > 0 then
					gap, side = gapLeft, -1
					t.eq(gapRight, 0, `puddle {i} should touch one wall`)
				end
				t.ok(gap >= 3 and gap <= 4, `puddle {i} dry path {gap}`)
				t.ok(side ~= lastGapSide, `puddle {i} dry path must switch sides (zigzag)`)
				lastGapSide = side
			end
			-- 웅덩이 줄 사이에 가로지르는 마른 길이 있어요 (웅덩이끼리 z가 겹치지 않음)
			for i = 2, #Layout.PUDDLES do
				local _, _, front = edges(Layout.PUDDLES[i])
				local _, _, _, prevBack = edges(Layout.PUDDLES[i - 1])
				t.ok(front <= prevBack - 3, `dry crossing between puddle {i - 1} and {i}`)
			end
		end
	)

	t.test("와사비 산: 높이 12~16, 패드에서 튀면 산 위로 올라가고 벽은 못 넘어요", function()
		local h = Layout.MOUNTAIN_HEIGHT
		t.ok(h >= 12 and h <= 16, `mountain height {h}`)
		-- 패드는 산 앞 평지에 있어요
		for i, pad in Layout.WASABI_PADS do
			local left, right, front, back = edges(pad)
			t.ok(front <= Layout.APPROACH.front and back > Layout.MOUNTAIN.front, `pad {i} not on approach`)
			local bodyLeft, bodyRight = edges(Layout.MOUNTAIN_BODY)
			t.ok(left >= bodyLeft and right <= bodyRight, `pad {i} must face the cliff`)
		end
		-- 위 속도만으로도(강제 구간 제외) 산 높이 + 여유 2를 넘어요
		local apex = Layout.WASABI_UP ^ 2 / (2 * GRAVITY)
		t.ok(apex >= h + 2, `wasabi apex {apex}`)
		-- 강제 구간(WASABI_HOLD)까지 더한 최고점 + 산 꼭대기에서 튀어도 벽보다 낮아요
		local highest = Layout.SLOPE_HIGH + Layout.WASABI_UP * Layout.WASABI_HOLD + apex + 5
		t.ok(highest < Layout.WALL_HEIGHT, `walls too low for wasabi launch ({highest})`)
		-- 점프만으로는 산에 못 올라가요
		local jumpApex = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
		t.ok(jumpApex < h, "plain jump must not reach the mountain top")
	end)

	t.test(
		"와사비 산: 경사로는 지면 통로 끝(산 뒤쪽)에서 앞쪽 꼭대기로 되돌아 올라가요",
		function()
			local ramp = Layout.RAMP
			local bodyLeft, bodyRight, bodyFront, bodyBack = edges(Layout.MOUNTAIN_BODY)
			t.eq(bodyLeft, -Layout.WIDTH / 2)
			t.eq(bodyFront, Layout.MOUNTAIN.front)
			t.eq(ramp.x - ramp.width / 2, bodyRight, "ramp must sit right next to the mountain body")
			t.ok(ramp.x + ramp.width / 2 <= Layout.WIDTH / 2 - 3, "ground corridor beside the ramp must stay 3+ wide")
			t.eq(ramp.low, bodyBack, "ramp starts at ground where the corridor ends")
			t.ok(ramp.high > ramp.low and ramp.high <= bodyFront, "ramp climbs back toward the front")
			local slopeDeg = math.deg(math.atan(Layout.MOUNTAIN_HEIGHT / (ramp.high - ramp.low)))
			t.ok(slopeDeg < 30, `ramp too steep ({slopeDeg})`)
			local _, _, backFront, backBack = edges(Layout.MOUNTAIN_BACK)
			t.eq(backFront, bodyBack)
			t.eq(backBack, Layout.MOUNTAIN.back)
		end
	)

	t.test("날치알 내리막: 결승 쪽이 높고 산 꼭대기와 결승 단에 이어져요", function()
		t.eq(Layout.SLOPE_LOW, Layout.MOUNTAIN_HEIGHT)
		t.ok(Layout.SLOPE_HIGH > Layout.SLOPE_LOW)
		t.eq(Layout.slopeHeightAt(Layout.SLOPE.front), Layout.SLOPE_LOW)
		t.eq(Layout.slopeHeightAt(Layout.SLOPE.back), Layout.SLOPE_HIGH)
		t.ok(
			Layout.BALL_SPAWN_Z < Layout.SLOPE.front and Layout.BALL_SPAWN_Z > Layout.SLOPE.back,
			"ball spawns on slope"
		)
		t.ok(Layout.BALL_DIAMETER >= 4 and Layout.BALL_DIAMETER <= 6, "ball diameter 4~6")
		t.ok(Layout.BALL_SPAWN_HALF_WIDTH + Layout.BALL_DIAMETER / 2 <= Layout.WIDTH / 2, "ball spawns inside walls")
		t.ok(Layout.BALL_INTERVAL_MIN >= 2 and Layout.BALL_INTERVAL_MAX <= 3, "ball interval 2~3s")
	end)

	t.test("결승선: 결승 구간 안, 끝 벽 앞에 서 있을 자리가 있어요", function()
		local z = Layout.finishLineZ()
		t.ok(z < Layout.FINISH.front and z > Layout.FINISH.back + 2, `finish line z {z}`)
	end)

	t.test("판 위 판정: 발자국 안·높이 범위 안일 때만", function()
		local function above(x: number, y: number, z: number): boolean
			return Layout.isAbovePlate(x, y, z, 20, 10, 1, Layout.SOY_ZONE_HEIGHT)
		end
		t.ok(above(0, 3, 0), "standing in the middle")
		t.ok(above(9.9, 3, -4.9), "near the corner")
		t.ok(not above(10.5, 3, 0), "outside x")
		t.ok(not above(0, 3, 5.5), "outside z")
		t.ok(not above(0, Layout.SOY_ZONE_HEIGHT + 1, 0), "jumping over")
		t.ok(not above(0, -2, 0), "below the plate")
	end)

	t.test("간장 속도는 기본 속도의 50%", function()
		t.eq(Layout.soyWalkSpeed(Config.Character.WalkSpeed), Config.Character.WalkSpeed * 0.5)
	end)

	t.test("날치알 공 수명: 8초, 내리막 아래 끝을 지나거나 떨어지면 사라져요", function()
		local onSlopeZ = (Layout.SLOPE.front + Layout.SLOPE.back) / 2
		t.ok(not Layout.ballExpired(1, onSlopeZ, 15))
		t.ok(Layout.ballExpired(Layout.BALL_LIFETIME, onSlopeZ, 15))
		t.ok(Layout.ballExpired(1, Layout.SLOPE.front + 0.5, 12))
		t.ok(Layout.ballExpired(1, onSlopeZ, -Layout.FALL_DEPTH - 1))
	end)

	t.test("쿨다운: 같은 키는 duration 동안 막히고 다른 키는 따로", function()
		local cd = Layout.newCooldown(1)
		t.ok(cd.tryUse("a", 10))
		t.ok(not cd.tryUse("a", 10.5))
		t.ok(cd.tryUse("b", 10.5))
		t.ok(cd.tryUse("a", 11))
		cd.forget("a")
		t.ok(cd.tryUse("a", 11.2))
	end)
end
