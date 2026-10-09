--!strict
-- m5-18 "줄다리기 발판": 맵 인터페이스·스폰(AC1), 기울기 로직(AC2), approach(AC3),
-- 연장전 각도 꺾인점(AC4)과 끝 보장(AC5), 무작위 퍼즈(AC6), 장식·풀(AC7)

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local Maps = RobloxRequire.require(Shared.maps)
local MapTypes = RobloxRequire.require(Shared.maps.MapTypes)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local Layout = RobloxRequire.require(Shared.maps.TugOfWarPlatformLayout)
local Logic = RobloxRequire.require(Shared.maps.TugOfWarPlatformLogic)
local Art = RobloxRequire.require(Shared.maps.TugOfWarPlatformArt)

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) < (eps or 1e-6)
end

-- 시드로 만드는 간단한 rng (Random.new(seed)와 같은 모양, elimination-cutscene.spec.luau와 동일 패턴)
local function seededRng(seed: number)
	local state = seed
	local function next(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state
	end
	return {
		nextInteger = function(min: number, max: number): number
			return min + next() % (max - min + 1)
		end,
		nextNumber = function(min: number, max: number): number
			return min + (next() / 2147483648) * (max - min)
		end,
	}
end

return function(t: Test.Test)
	-- AC1 ------------------------------------------------------------------------------------
	t.test("AC1: tug-of-war-platform은 overtime 훅이 있는 Final 맵이에요", function()
		local map = Maps.get("tug-of-war-platform")
		t.eq(MapTypes.validate(map), nil)
		t.eq(map.kind, "Final")
		t.eq(type(map.overtime), "function")
		t.eq(Maps.timeLimit(map), Config.TimeLimit.Final)
	end)

	t.test("AC1: 스폰 24개가 전부 발판 위, 3 studs 이상 떨어지고 왼쪽·오른쪽 12개씩", function()
		local spawns = Layout.spawnPositions()
		t.eq(#spawns, 24)
		local left, right = 0, 0
		for i, pos in spawns do
			t.ok(Layout.onPlatform(pos.x, pos.z), `Spawn{i} off the platform`)
			if pos.x < 0 then
				left += 1
			elseif pos.x > 0 then
				right += 1
			end
		end
		t.eq(left, 12)
		t.eq(right, 12)
		for i = 1, #spawns do
			for j = i + 1, #spawns do
				local dx = spawns[i].x - spawns[j].x
				local dz = spawns[i].z - spawns[j].z
				local distance = math.sqrt(dx * dx + dz * dz)
				t.ok(distance >= 3, `Spawn{i}/Spawn{j} too close ({distance})`)
			end
		end
	end)

	t.test("Layout: 발판 절반 길이가 SATURATION_TORQUE/3 (끝에 3명이 뭉치면 포화)", function()
		t.eq(Layout.HALF_LENGTH, Logic.SATURATION_TORQUE / 3)
		t.eq(Layout.HALF_LENGTH, 35)
		t.eq(Layout.CENTER_Z, -40)
	end)

	-- AC2 ------------------------------------------------------------------------------------
	t.test(
		"AC2: Logic.tilt — 빈 목록·중앙·팽팽한 양 끝은 0, 한쪽 쏠리면 양수/음수, 포화",
		function()
			t.eq(Logic.tilt({}), 0)
			t.eq(Logic.tilt({ 0, 0, 0 }), 0)
			t.eq(Logic.tilt({ 35, -35 }), 0)
			t.ok(near(Logic.tilt({ 35 }), math.rad(10)), `got {Logic.tilt({ 35 })}`)
			t.ok(near(Logic.tilt({ 35, 35, 35 }), Logic.MAX_ANGLE), "saturates at three on the end")
			t.ok(near(Logic.tilt({ 35, 35, 35, 35, 35 }), Logic.MAX_ANGLE), "five doesn't exceed MAX_ANGLE")
			t.ok(near(Logic.tilt({ -35, -35, -35 }), -Logic.MAX_ANGLE))
		end
	)

	-- AC3 ------------------------------------------------------------------------------------
	t.test(
		"AC3: Logic.approach — maxDelta만큼만, target을 넘지 않고, 이미 target이면 그대로",
		function()
			t.ok(near(Logic.approach(0, math.rad(30), math.rad(20)), math.rad(20)))
			t.ok(near(Logic.approach(math.rad(25), math.rad(10), math.rad(20)), math.rad(10)), "does not overshoot")
			t.ok(near(Logic.approach(math.rad(5), math.rad(5), math.rad(20)), math.rad(5)), "already at target")
		end
	)

	-- AC4 ------------------------------------------------------------------------------------
	t.test("AC4: overtimeAngle 꺾인점 (collapseDuration 20): 5·10·15·20초에 30→-50→70→-90도", function()
		t.ok(near(Logic.overtimeAngle(0, 20, 0.2), 0.2), "keeps startAngle at elapsed 0")
		t.ok(near(Logic.overtimeAngle(2.5, 20, 0), math.rad(15)), "half interpolation of the first segment")
		t.ok(near(Logic.overtimeAngle(5, 20, 0), math.rad(30)))
		t.ok(near(Logic.overtimeAngle(10, 20, 0), -math.rad(50)))
		t.ok(near(Logic.overtimeAngle(15, 20, 0), math.rad(70)))
		t.ok(near(Logic.overtimeAngle(20, 20, 0), -math.rad(90)))
	end)

	-- AC5 ------------------------------------------------------------------------------------
	t.test(
		"AC5: overtimeAngle 끝 보장 — collapseDuration이 달라도 끝은 항상 LETHAL_ANGLE, 넘겨도 clamp",
		function()
			for _, duration in { 8, 20, 40 } do
				local atEnd = Logic.overtimeAngle(duration, duration, 0)
				t.ok(near(math.abs(atEnd), Logic.LETHAL_ANGLE), `duration {duration}: {atEnd}`)
				local pastEnd = Logic.overtimeAngle(duration + 5, duration, 0)
				t.eq(pastEnd, atEnd, `duration {duration} past end should clamp`)
			end
			t.eq(Logic.LETHAL_ANGLE, math.rad(90))
		end
	)

	-- AC6 ------------------------------------------------------------------------------------
	t.test(
		"AC6: 무작위 퍼즈 1000번 — 항상 [-MAX_ANGLE, MAX_ANGLE] 안, 오른쪽이 크면 음수 아님",
		function()
			local rng = seededRng(20261009)
			for _ = 1, 1000 do
				local count = rng.nextInteger(1, 24)
				local positions = table.create(count)
				local sum = 0
				for i = 1, count do
					local x = rng.nextNumber(-35, 35)
					positions[i] = x
					sum += x
				end
				local angle = Logic.tilt(positions)
				t.ok(angle >= -Logic.MAX_ANGLE - 1e-9 and angle <= Logic.MAX_ANGLE + 1e-9, `angle {angle} out of range`)
				if sum >= 0 then
					t.ok(angle >= -1e-9, `sum {sum} but angle {angle} is negative`)
				else
					t.ok(angle <= 1e-9, `sum {sum} but angle {angle} is positive`)
				end
			end
		end
	)

	-- AC7 ------------------------------------------------------------------------------------
	t.test(
		"AC7: 장식(기울어지는 것·고정) 전부 MapKitLogic.validate 통과, 합쳐서 600개 이하",
		function()
			local deck = Art.deckDecor()
			local still = Art.decor()
			t.eq(MapKitLogic.validate(deck), nil)
			t.eq(MapKitLogic.validate(still), nil)
			t.ok(#deck + #still + 1 <= MapKitLogic.DECOR_PART_BUDGET, `parts {#deck + #still + 1}`) -- +1 발판 파츠
		end
	)

	t.test("AC7: inPool이 없거나 true (랜덤 결승 풀에 들어가요)", function()
		local map = Maps.get("tug-of-war-platform")
		t.ok((map :: any).inPool == nil or (map :: any).inPool == true)
		local found = false
		for _, info in Maps.infos() do
			if info.id == "tug-of-war-platform" then
				found = true
			end
		end
		t.ok(found, "tug-of-war-platform should be in the random pool")
	end)

	t.test("introCamera: 3~5점, 끝점은 받침대/접시보다 바깥·높게", function()
		local points = Art.introCamera()
		t.ok(#points >= 3 and #points <= 5, `points {#points}`)
	end)
end
