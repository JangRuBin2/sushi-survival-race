--!strict
-- m2-02 QA(docs/qa/m2-02-race-soy-swamp.md)에서 추가한 코스 기하·튜닝 성질 테스트 (SoySwampLayout만 사용)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Layout = RobloxRequire.require(Shared.maps.SoySwampLayout)

local GRAVITY = 196.2
local BODY_HALF_WIDTH = 1 -- 캐릭터 몸 반폭 (근사)
local STAND_ROOT_Y = 3 -- 서 있을 때 바닥 기준 루트 높이

local function jumpAirtime(): number
	return 2 * Config.Character.JumpPower / GRAVITY
end

return function(t: Test.Test)
	t.test(
		"간장 늪: 웅덩이를 한 번도 밟지 않고 늪 앞에서 뒤까지 가는 마른 길이 있어요 (0.5 studs 격자 BFS)",
		function()
			local step = 0.5
			local half = Layout.WIDTH / 2
			local function soaked(x: number, z: number): boolean
				-- 루트 중심이 웅덩이 발자국 안이면 간장 (SoySwampHazards와 같은 기준). 벽에서는 몸 반폭만큼 떨어져야 해요.
				if math.abs(x) > half - BODY_HALF_WIDTH then
					return true
				end
				for _, box in Layout.PUDDLES do
					if math.abs(x - box.x) <= box.width / 2 and math.abs(z - box.z) <= box.depth / 2 then
						return true
					end
				end
				return false
			end
			local cols = math.floor((2 * half) / step)
			local rows = math.floor((Layout.SWAMP.front - Layout.SWAMP.back) / step)
			local function pos(c: number, r: number): (number, number)
				return -half + c * step, Layout.SWAMP.front - r * step
			end
			local seen: { [number]: boolean } = {}
			local queue = {}
			for c = 0, cols do
				local x, z = pos(c, 0)
				if not soaked(x, z) then
					table.insert(queue, { c, 0 })
					seen[c * 10000] = true
				end
			end
			local reached = false
			local head = 1
			while head <= #queue do
				local c, r = queue[head][1], queue[head][2]
				head += 1
				if r == rows then
					reached = true
					break
				end
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nc, nr = c + d[1], r + d[2]
					local key = nc * 10000 + nr
					if nc >= 0 and nc <= cols and nr >= 0 and nr <= rows and not seen[key] then
						local x, z = pos(nc, nr)
						if not soaked(x, z) then
							seen[key] = true
							table.insert(queue, { nc, nr })
						end
					end
				end
			end
			t.ok(reached, "no dry route through the swamp")
		end
	)

	t.test(
		"간장 늪: 점프 한 번(걷는 속도)으로는 웅덩이 하나를 통째로 건너뛰지 못해요",
		function()
			local horizontal = Config.Character.WalkSpeed * jumpAirtime()
			for i, box in Layout.PUDDLES do
				t.ok(horizontal < box.depth, `puddle {i}: jump covers {horizontal} >= depth {box.depth}`)
			end
		end
	)

	t.test("간장 안 판정: 서 있으면 간장, 점프 최고점에서는 간장 밖", function()
		local jumpApex = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
		local plateCenter = 0.1 + Layout.PUDDLE_DEPTH / 2
		local standingRel = STAND_ROOT_Y - plateCenter
		local apexRel = STAND_ROOT_Y + jumpApex - plateCenter
		t.ok(Layout.isAbovePlate(0, standingRel, 0, 20, 10, 1, Layout.SOY_ZONE_HEIGHT), "standing should be soaked")
		t.ok(not Layout.isAbovePlate(0, apexRel, 0, 20, 10, 1, Layout.SOY_ZONE_HEIGHT), "apex should be outside")
	end)

	t.test(
		"와사비: 패드 어디서 튀어도(위 80·앞 30, 공기 저항 없음) 산 몸통 위에 착지해요",
		function()
			local h = Layout.MOUNTAIN_HEIGHT
			local up = Layout.WASABI_UP
			-- y(t) = up·t − g/2·t² 가 다시 산 높이가 되는 시각 (내려오는 쪽)
			local tLand = (up + math.sqrt(up * up - 2 * GRAVITY * h)) / GRAVITY
			local bodyFront = Layout.MOUNTAIN_BODY.z + Layout.MOUNTAIN_BODY.depth / 2
			local bodyBack = Layout.MOUNTAIN_BODY.z - Layout.MOUNTAIN_BODY.depth / 2
			for i, pad in Layout.WASABI_PADS do
				for _, startZ in { pad.z + pad.depth / 2, pad.z, pad.z - pad.depth / 2 } do
					local landZ = startZ - Layout.WASABI_FORWARD * tLand
					t.ok(landZ < bodyFront and landZ > bodyBack, `pad {i} from z {startZ} lands at {landZ}`)
				end
			end
		end
	)

	t.test(
		"날치알: 동시에 있는 공은 많아야 수명/최소 간격 + 1개 (AC7 '쌓이지 않음')",
		function()
			local maxBalls = math.ceil(Layout.BALL_LIFETIME / Layout.BALL_INTERVAL_MIN) + 1
			t.ok(maxBalls <= 6, `up to {maxBalls} balls`)
		end
	)

	t.test("날치알: 서서 맞고, 점프 최고점에서는 공 위로 넘어가요", function()
		local hitRange = Layout.BALL_DIAMETER / 2 + Layout.BALL_HIT_EXTRA
		local ballCenterY = Layout.BALL_DIAMETER / 2 -- 바닥 기준
		local jumpApex = Config.Character.JumpPower ^ 2 / (2 * GRAVITY)
		t.ok(math.abs(STAND_ROOT_Y - ballCenterY) <= hitRange, "standing next to a ball should hit")
		t.ok(STAND_ROOT_Y + jumpApex - ballCenterY > hitRange, "jump apex should clear the ball")
	end)

	t.test(
		"공은 내리막을 벗어나면 바로 사라지고(산 위로 굴러가지 않음), 내리막 위에서는 수명 전까지 남아요",
		function()
			for z = Layout.SLOPE.back + 1, Layout.SLOPE.front - 1, 4 do
				t.ok(not Layout.ballExpired(0, z, Layout.slopeHeightAt(z)), `z {z}`)
			end
			t.ok(Layout.ballExpired(0, Layout.SLOPE.front + 0.01, Layout.SLOPE_LOW))
		end
	)
end
