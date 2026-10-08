--!strict
-- m4-02 QA: 회전 벨트 스폰 수정 근거(옛 위치가 허공이었는지)와 경계값(간격·캐릭터 여유·벨트 구역 밖),
-- 아트 모듈이 옮겨 적은 치수가 RotatingBelt.luau 소스와 같은지, 소개 카메라 경로(경유점 사이)가 장식을
-- 지나가지 않는지, 벨트 밀기 면제 간격이 면제 시간보다 짧은지, 판정 파츠 재질 변경마다 물리 유지.

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local BeltArt = RobloxRequire.require(Shared.maps.RotatingBeltArt)

local BELT_PATH = "src/shared/maps/RotatingBelt.luau"

local function stripComments(source: string): string
	source = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	return (string.gsub(source, "%-%-[^\n]*", ""))
end

-- RotatingBelt.luau의 `local NAME = <number>` 상수
local function constant(source: string, name: string): number
	local value = string.match(source, `\nlocal {name} = (%-?[%d%.]+)`)
	assert(value, `constant {name} not found`)
	return tonumber(value) :: number
end

-- 캐릭터 충돌 몸통 폭 (R6 Torso·R15 UpperTorso·HumanoidRootPart 모두 2 studs, 팔다리는 충돌하지 않음)
local TORSO_WIDTH = 2

return function(t: Test.Test)
	local belt = stripComments(fs.readFile(BELT_PATH))
	local DEPTH_START = constant(belt, "DEPTH_START")
	local DEPTH_BELT_A = constant(belt, "DEPTH_BELT_A")
	local DEPTH_NARROW = constant(belt, "DEPTH_NARROW")
	local DEPTH_BELT_B = constant(belt, "DEPTH_BELT_B")
	local DEPTH_FINISH = constant(belt, "DEPTH_FINISH")
	local WIDTH_NORMAL = constant(belt, "WIDTH_NORMAL")
	local WIDTH_NARROW = constant(belt, "WIDTH_NARROW")
	local START_HALF = (WIDTH_NORMAL + 4) / 2 -- 출발 바닥 폭 20 → x ±10
	local START_BACK = -DEPTH_START -- 출발 바닥 z 0 ~ -14 (그 뒤는 벨트 A·Conveyor 구역)

	t.test(
		"스폰 근거: 옛 식(M1~M3)은 12개가 출발 바닥 뒤 허공, 8개가 바닥 끝(x ±10)에 걸쳤어요",
		function()
			local startCenter = -DEPTH_START / 2
			local inVoid, onEdge = 0, 0
			for row = 0, 3 do
				for col = 0, 5 do
					local x = (col - 2.5) * 4
					local z = startCenter + 2 + row * 4
					if z > 0 then
						inVoid += 1 -- 출발 바닥은 z 0 ~ -14. 그 뒤(+z)에는 바닥도 벽도 없어요.
					end
					if math.abs(x) + 1.5 > START_HALF then
						onEdge += 1
					end
				end
			end
			t.eq(inVoid, 12, "old Spawn13~24 behind the start floor")
			t.eq(onEdge, 8, "old outer columns hang over the floor edge")
		end
	)

	t.test(
		"스폰: 새 위치 24개가 출발 바닥 안쪽, 벨트 구역(z < -14) 밖, 이름순 앞줄부터",
		function()
			local positions = BeltArt.spawnPositions()
			t.eq(#positions, Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions])
			local half = BeltArt.SPAWN_SIZE / 2
			for i, pos in positions do
				t.ok(math.abs(pos.x) + half <= START_HALF - 1, `spawn {i} x {pos.x}`)
				t.ok(pos.z + half <= 0 - 1, `spawn {i} in front of the floor edge`)
				t.ok(pos.z - half >= START_BACK + 1, `spawn {i} before the conveyor zone ({pos.z})`)
			end
			-- 혼자 시작하면 Spawn01: 바닥 위
			t.ok(positions[1].z <= -2.5, "Spawn01 on the floor")
			-- 1번 줄(1~6)이 가장 앞(+z), 줄이 늘수록 코스 쪽(-z)
			t.ok(positions[1].z > positions[7].z and positions[7].z > positions[13].z, "rows go down the course")
		end
	)

	t.test("스폰: 간격 3 — 판끼리 겹치지 않고 캐릭터 몸통(폭 2) 사이 1 stud 이상", function()
		local positions = BeltArt.spawnPositions()
		local minDx, minDist = math.huge, math.huge
		for i = 1, #positions do
			for j = i + 1, #positions do
				local a, b = positions[i], positions[j]
				local dx, dz = math.abs(a.x - b.x), math.abs(a.z - b.z)
				-- 판(3×3)이 겹치지 않음: x나 z 중 하나는 판 크기 이상 떨어져요
				t.ok(dx >= BeltArt.SPAWN_SIZE - 1e-6 or dz >= BeltArt.SPAWN_SIZE - 1e-6, `plates {i},{j} overlap`)
				minDist = math.min(minDist, math.sqrt(dx * dx + dz * dz))
				if dz < 1e-6 then
					minDx = math.min(minDx, dx)
				end
			end
		end
		t.eq(minDx, BeltArt.SPAWN_SPACING)
		t.ok(minDist - TORSO_WIDTH >= 1, `torso gap {minDist - TORSO_WIDTH}`)
	end)

	t.test(
		"치수: 아트 SECTIONS·결승선·간장 종지 위치가 RotatingBelt.luau 소스 상수와 같아요",
		function()
			local depths = { DEPTH_START, DEPTH_BELT_A, DEPTH_NARROW, DEPTH_BELT_B, DEPTH_FINISH }
			local widths = { WIDTH_NORMAL + 4, WIDTH_NORMAL, WIDTH_NARROW, WIDTH_NORMAL, WIDTH_NORMAL + 4 }
			local cursor = 0
			for i, section in BeltArt.SECTIONS do
				t.eq(section.front, cursor, `section {i} front`)
				cursor -= depths[i]
				t.eq(section.back, cursor, `section {i} back`)
				t.eq(section.half * 2, widths[i], `section {i} width`)
			end
			t.eq(BeltArt.FINISH_LINE_Z, cursor + constant(belt, "FINISH_LINE_INSET"))
			t.eq(BeltArt.WALL_HEIGHT, constant(belt, "WALL_HEIGHT"))
			-- 종지: x = WIDTH_NARROW / 2 + 1.5, z = narrowCenter - D/3 + row * D/3
			t.eq(BeltArt.SOY_DISH_X, WIDTH_NARROW / 2 + 1.5)
			local narrowCenter = -(DEPTH_START + DEPTH_BELT_A) - DEPTH_NARROW / 2
			local zs = {}
			for row = 0, 2 do
				table.insert(zs, narrowCenter - DEPTH_NARROW / 3 + row * (DEPTH_NARROW / 3))
			end
			table.sort(zs)
			local art = table.clone(BeltArt.SOY_DISH_ZS)
			table.sort(art)
			for i = 1, 3 do
				t.eq(art[i], zs[i], `soy dish z {i}`)
			end
			t.ok(string.find(belt, "side * (WIDTH_NARROW / 2 + 1.5)", 1, true) ~= nil, "soy dish x formula unchanged")
		end
	)

	t.test(
		"소개 카메라(회전 벨트): 경유점 사이 경로도 장식·벽 속을 지나가지 않아요",
		function()
			local path = {}
			for _, point in BeltArt.introCamera() do
				table.insert(path, { position = point.pos, lookAt = point.lookAt })
			end
			local boxes = {}
			for _, spec in BeltArt.decor() do
				table.insert(boxes, { name = spec.name, b = MapKitLogic.bounds({ spec }) :: MapKitLogic.Bounds })
			end
			local hits: { [string]: boolean } = {}
			local steps = 1000
			for s = 0, steps do
				local p = IntroCameraLogic.sample(path, s / steps).position
				for _, entry in boxes do
					local b = entry.b
					if
						p.x > b.min.x
						and p.x < b.max.x
						and p.y > b.min.y
						and p.y < b.max.y
						and p.z > b.min.z
						and p.z < b.max.z
					then
						hits[entry.name] = true
					end
				end
				-- 벽(높이 6)보다 위이거나 벽 안쪽이에요
				t.ok(p.y > BeltArt.WALL_HEIGHT or math.abs(p.x) < 8, `camera inside a wall at {p.x},{p.y},{p.z}`)
			end
			for name in hits do
				t.ok(false, `intro path passes through decor {name}`)
			end
		end
	)

	t.test(
		"이동 감시: 벨트 면제 갱신 간격이 면제 시간보다 짧아 밀리는 동안 빈틈이 없어요",
		function()
			local refresh = constant(belt, "CONVEYOR_EXEMPT_REFRESH")
			t.ok(refresh < Config.MovementGuard.ExemptAfterServerMove, `refresh {refresh}`)
			-- 젓가락 잡기 면제(GRAB + 1)는 잡힌 시간보다 길어요
			local chop = stripComments(fs.readFile("src/shared/maps/RotatingBeltChopstick.luau"))
			t.ok(string.find(chop, "MoveExempt.mark(character, GRAB_DURATION + 1)", 1, true) ~= nil, "grab exempt")
		end
	)

	t.test(
		"물리 유지: 회전 벨트에서 Material을 바꾼 판정 파츠는 모두 CustomPhysicalProperties를 같이 둬요",
		function()
			-- addFloor는 material·physics를 둘 다 받아요 → 호출마다 6개 인자
			local floorCalls = 0
			for args in string.gmatch(belt, "addFloor(%b())") do
				if string.find(args, ": number", 1, true) == nil then -- 함수 정의는 빼요
					floorCalls += 1
					local _, commas = string.gsub(args, ",", "")
					t.ok(commas >= 5, `addFloor call passes physics: {args}`)
				end
			end
			t.eq(floorCalls, 5, "start, belt A, narrow, belt B, finish floors")
			t.ok(
				string.find(belt, "CustomPhysicalProperties = PhysicalProperties.new(physics)", 1, true) ~= nil,
				"addFloor applies physics"
			)
			t.ok(
				string.find(belt, "CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.Plastic)", 1, true)
					~= nil,
				"soy dish keeps M3 Plastic physics"
			)
		end
	)
end
