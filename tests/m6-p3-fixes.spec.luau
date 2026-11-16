--!strict
-- m6 QA P3 고침 회귀 (2026-11-15): 회전 원판 그릇이 출발 순간 스폰과 겹치지 않음(m6-06 P3-1),
-- 도시락 옆 벽이 튕김판 꼭대기보다 높음(m6-04 P3-2), 다이너마이트 떨어뜨릴 자리 바닥 검사(m6-12 P3-2).

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local DynamiteLogic = RobloxRequire.require(Shared.DynamiteLogic)
local LLayout = RobloxRequire.require(Shared.maps.LazySusanLayout)
local LLogic = RobloxRequire.require(Shared.maps.LazySusanLogic)
local BDLayout = RobloxRequire.require(Shared.maps.BentoDoorDashLayout)
local SushiBody = RobloxRequire.require(Shared.SushiBody)

return function(t: Test.Test)
	t.test(
		"회전 원판: 출발 뒤 1초 동안 어느 스폰도 반찬 그릇 판정(반지름 + 여유) 안에 없어요",
		function()
			local hitR = LLayout.BOWL_RADIUS + LLayout.BOWL_HIT_PAD
			local spawns = LLayout.spawnPositions()
			t.eq(#spawns, 40)
			-- 서 있는 사람은 자기 고리와 같이 돌아요: 스폰 자리도 그 고리 각도만큼 돌려서 비교해요
			local function ringOf(r: number)
				for _, ring in LLayout.RINGS do
					if r >= ring.inner and r <= ring.outer then
						return ring
					end
				end
				return nil
			end
			for step = 0, 10 do
				local time = step / 10
				for _, bowl in LLayout.BOWLS do
					local bx, bz = LLogic.bowlPosition(bowl, time)
					for i, s in spawns do
						local r = math.sqrt(s.x * s.x + s.z * s.z)
						local ring = ringOf(r)
						t.ok(ring ~= nil, `spawn {i} on a ring`)
						local a = math.atan2(s.z, s.x) + math.rad(LLogic.ringAngle(ring, time))
						local d = math.sqrt((math.cos(a) * r - bx) ^ 2 + (math.sin(a) * r - bz) ^ 2)
						t.ok(d > hitR + 1, `spawn {i} vs bowl {bowl.index} at t={time}: {d}`)
					end
				end
			end
		end
	)

	t.test("회전 원판 스펙: 그릇은 점프가 아니라 옆 고리로 피한다고 적어요", function()
		local spec = fs.readFile("docs/specs/m6-06-lazy-susan.md")
		t.eq(string.find(spec, "점프로 넘어요", 1, true), nil)
		t.ok(string.find(spec, "옆 고리로 비켜 피해요", 1, true) ~= nil)
	end)

	t.test(
		"도시락: 옆 벽은 문 벽과 같은 높이이고 튕김판 꼭대기(발 약 12.7)보다 높아요",
		function()
			t.eq(BDLayout.SIDE_WALL_HEIGHT, BDLayout.WALL_HEIGHT)
			t.ok(BDLayout.SIDE_WALL_HEIGHT >= 13.5, `side wall {BDLayout.SIDE_WALL_HEIGHT}`)
		end
	)

	t.test("다이너마이트 floorOk: 바닥이 없거나 발 높이와 멀면 안 돼요", function()
		local tol = Config.Dynamite.DropFloorTolerance
		t.eq(tol, 3)
		t.ok(Config.Dynamite.DropTries >= 3)
		t.eq(DynamiteLogic.floorOk(10, nil, tol), false, "air")
		t.ok(DynamiteLogic.floorOk(10, 10, tol), "same floor")
		t.ok(DynamiteLogic.floorOk(10, 7, tol), "step down at tolerance")
		t.ok(DynamiteLogic.floorOk(10, 13, tol), "step up at tolerance")
		t.eq(DynamiteLogic.floorOk(10, 6.9, tol), false, "lower floor")
		t.eq(DynamiteLogic.floorOk(10, 24, tol), false, "wall top")
	end)

	t.test(
		"다이너마이트 서버: 바닥 광선 + 자리 비었는지 확인한 뒤에만 떨어뜨려요",
		function()
			local src = fs.readFile("src/server/DynamiteService.luau")
			t.ok(string.find(src, "local position = findDropPosition(list, racers)", 1, true) ~= nil)
			t.ok(string.find(src, "DynamiteLogic.floorOk(footY, hitY, tolerance)", 1, true) ~= nil)
			t.ok(string.find(src, "Workspace:GetPartBoundsInBox(", 1, true) ~= nil, "clearance check")
			t.ok(string.find(src, "RespectCanCollide = true", 1, true) ~= nil, "decor ignored")
			-- 발바닥 거리는 SushiBody.GROUND_OFFSET과 같아요 (서버는 SushiBody를 직접 싣지 않음)
			local offset = tonumber(string.match(src, "local FOOT_OFFSET = ([%d%.]+)"))
			t.eq(offset, SushiBody.GROUND_OFFSET)
		end
	)
end
