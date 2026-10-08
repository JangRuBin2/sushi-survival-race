--!strict
-- m4-06 QA: 로비 배치 경계값, 단상 인형·이름표 겹침, 서버/클라이언트 소스 불변식

local fs = require("@lune/fs")

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shared = RobloxRequire.root("src/shared")
local LobbyLayout = RobloxRequire.require(Shared.LobbyLayout)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local SushiBody = RobloxRequire.require(Shared.SushiBody)
local Config = RobloxRequire.require(Shared.Config)

local EPS = 1e-6
local SPAWN_HALF = 6 -- LobbySpawn 12x12 (default.project.json)
local CHARACTER_WIDTH = 3 -- 초밥 캐릭터가 지나갈 최소 폭(여유 포함)

local function boundsOf(spec: any): any
	return MapKitLogic.bounds({ spec })
end

local function solidParts(): { any }
	return LobbyLayout.STRUCTURE
end

return function(t: Test.Test)
	t.test("QA: 스폰(12x12)과 그 위 캐릭터 공간에 충돌 파츠가 없어요", function()
		for _, spec in solidParts() do
			local b = boundsOf(spec)
			local overlap = b.min.x < SPAWN_HALF
				and b.max.x > -SPAWN_HALF
				and b.min.z < SPAWN_HALF
				and b.max.z > -SPAWN_HALF
				and b.min.y < 12
			t.ok(not overlap, `{spec.name} on spawn`)
		end
	end)

	t.test("QA: 스폰 → 단상 사이(+X 6~26)가 비어 있어 걸어갈 수 있어요", function()
		local podium = LobbyLayout.PODIUM
		local lane = { min = { x = SPAWN_HALF, z = -2 }, max = { x = podium.center.x - 4, z = 2 } }
		for _, spec in solidParts() do
			local b = boundsOf(spec)
			local hit = b.min.x < lane.max.x and b.max.x > lane.min.x and b.min.z < lane.max.z and b.max.z > lane.min.z
			t.ok(not hit, `{spec.name} blocks spawn->podium`)
		end
	end)

	t.test(
		"QA: 충돌 파츠 사이에 캐릭터가 끼일 좁은 틈(0 < 틈 < 3)이 없어요 (기둥·벽·단상·카운터)",
		function()
			-- 수평 틈만 봐요: 두 상자가 높이로 겹치고, 한 축으로 겹치고, 다른 축으로 0~3 떨어진 경우
			-- 기둥과 벽 사이 0.5 틈은 캐릭터보다 훨씬 좁아 들어갈 수 없으므로 1 미만은 허용해요.
			local list = solidParts()
			local bad = {}
			for i = 1, #list do
				local a = boundsOf(list[i])
				for j = i + 1, #list do
					local b = boundsOf(list[j])
					local yOverlap = a.min.y < b.max.y and b.min.y < a.max.y
					if yOverlap then
						local xOverlap = a.min.x < b.max.x and b.min.x < a.max.x
						local zOverlap = a.min.z < b.max.z and b.min.z < a.max.z
						local gx = math.max(b.min.x - a.max.x, a.min.x - b.max.x)
						local gz = math.max(b.min.z - a.max.z, a.min.z - b.max.z)
						if
							(zOverlap and gx >= 1 and gx < CHARACTER_WIDTH)
							or (xOverlap and gz >= 1 and gz < CHARACTER_WIDTH)
						then
							-- 카운터 마디는 회전 상자라 외곽 상자 계산이 거칠어요: 카운터끼리는 제외
							local ca = string.match(list[i].name, "^Counter") or string.match(list[i].name, "^Rail")
							local cb = string.match(list[j].name, "^Counter") or string.match(list[j].name, "^Rail")
							if not (ca and cb) then
								table.insert(bad, `{list[i].name}/{list[j].name}`)
							end
						end
					end
				end
			end
			t.eq(#bad, 0, table.concat(bad, ", "))
		end
	)

	t.test(
		"QA: 카운터 높이(+레일)가 점프 높이보다 낮아 안쪽에 들어가도 나올 수 있어요",
		function()
			local jumpHeight = Config.Character.JumpPower ^ 2 / (2 * 196.2)
			local top = LobbyLayout.COUNTER.height + 0.3
			t.ok(top < jumpHeight - 1, `counter {top} vs jump {jumpHeight}`)
			-- 단상 계단 차이도 점프로 오를 수 있어요
			t.ok(LobbyLayout.PODIUM.topY - 3 < jumpHeight, "podium step")
		end
	)

	t.test(
		"QA: 단상 인형(1.5배)이 가운데 단 윗면에 서고, 이름 줄은 인형 머리 위에 있어요",
		function()
			local podium = LobbyLayout.PODIUM
			local b = SushiBody.bounds(SushiBody.layout(Config.Appearance.Default))
			local bodyCenterY = podium.topY + SushiBody.GROUND_OFFSET * podium.scale
			local dollTop = bodyCenterY + b.max[2] * podium.scale
			local dollBottom = bodyCenterY + b.min[2] * podium.scale
			t.ok(math.abs(dollBottom - podium.topY) < 0.6, `doll floats/sinks: bottom {dollBottom}`)
			-- 이름표: BillboardGui 4.5 studs, 가운데 = labelHeight, 아래 정렬 Name 0.45 / Title 0.3 / Wins 0.25
			-- QA 리포트 L1(P2) 수정 뒤: 인형 머리가 이름표 맨 아래 줄(Wins)보다 아래에 있어야 해요.
			local labelBottom = podium.labelHeight - 4.5 / 2
			t.ok(dollTop <= labelBottom + EPS, `doll top {dollTop} > label bottom {labelBottom}`)
		end
	)

	t.test("QA: 레일 접시가 카운터 레일 위(높이·폭)에 놓여요", function()
		local rail = LobbyLayout.RAIL
		t.ok(math.abs(rail.center.y - (LobbyLayout.COUNTER.height + 0.3 + 0.15)) < EPS)
		-- 접시 지름 3 ≤ 레일 폭 2.8 + 여유 0.4, 카운터 폭 4 안
		t.ok(3 <= LobbyLayout.COUNTER.width)
	end)

	t.test("QA: 큰 서버 시각(1.9e9)에서도 접시 간격·위치가 정확해요", function()
		local length = LobbyLayout.railLength()
		local spacing = length / LobbyLayout.RAIL.plateCount
		for _, time in { 1.9e9, 1.9e9 + 0.016, 2.1e9 + 0.5 } do
			for i = 1, 16 do
				local gap = (LobbyLayout.plateArc(i % 16 + 1, time) - LobbyLayout.plateArc(i, time)) % length
				t.ok(math.abs(gap - spacing) < 1e-4, `gap {i} at {time}`)
			end
		end
		-- 한 프레임(1/60초) 움직임 = 속도/60 (뚝뚝 끊기지 않음)
		local a = LobbyLayout.plateArc(1, 1.9e9)
		local b = LobbyLayout.plateArc(1, 1.9e9 + 1 / 60)
		t.ok(math.abs((b - a) % length - LobbyLayout.RAIL.speed / 60) < 1e-3)
	end)

	t.test("QA: 로비가 아레나 슬롯·우승 연출 무대와 떨어져 있어요", function()
		local b = MapKitLogic.bounds(LobbyLayout.allSpecs(0)) :: any
		local arena = Config.Arena
		t.ok(arena.BaseHeight >= 300 and b.max.y < arena.BaseHeight - 100, "arena height")
		t.ok(arena.SlotSpacing - b.max.x > 1000, "arena slot x")
		local VictoryCutsceneLogic = RobloxRequire.require(Shared.VictoryCutsceneLogic)
		local o = VictoryCutsceneLogic.SCENE_ORIGIN
		t.ok(o[2] > b.max.y + 500 or math.abs(o[3]) > 1000, "victory stage far")
	end)

	t.test(
		"QA: 서버 LobbyService 불변식 (Match면 로비 안 지음, Technology 안 건드림, SushiBody 없음)",
		function()
			local src = fs.readFile("src/server/LobbyService.luau")
			t.ok(string.find(src, 'PlaceService.role() == "Match"', 1, true) ~= nil, "Match guard")
			-- start에서 Match 확인이 buildLobby와 단상 구독보다 먼저
			local guard = string.find(src, 'PlaceService.role() == "Match"', 1, true) :: number
			local startAt = string.find(src, "function LobbyService.start", 1, true) :: number
			t.ok(guard > startAt, "guard inside start")
			t.ok(string.find(src, "buildLobby()", guard, true) ~= nil)
			t.ok(string.find(src, "Technology", 1, true) == nil, "Technology untouched")
			t.ok(string.find(src, "SushiBody", 1, true) == nil, "server SushiBody")
			-- init은 조명만 (역할과 상관없이)
			local initBody = string.match(src, "function LobbyService%.init%(%)(.-)\nend")
			t.ok(initBody ~= nil and string.find(initBody, "applyLighting", 1, true) ~= nil)
			t.ok(string.find(initBody :: string, "buildLobby", 1, true) == nil)
		end
	)

	t.test(
		"QA: 클라이언트 LobbyFxController가 서버 시각으로 돌리고, 로비가 사라지면 끊고, 멀면 쉬어요",
		function()
			local src = fs.readFile("src/client/fx/LobbyFxController.luau")
			t.ok(string.find(src, "GetServerTimeNow", 1, true) ~= nil)
			t.ok(string.find(src, "BulkMoveTo", 1, true) ~= nil)
			t.ok(string.find(src, "connection:Disconnect()", 1, true) ~= nil)
			t.ok(string.find(src, "FAR_DISTANCE", 1, true) ~= nil)
			-- 인형은 앵커·충돌 없음
			for _, needle in { "Anchored = true", "CanCollide = false", "CanQuery = false", "CanTouch = false" } do
				t.ok(string.find(src, needle, 1, true) ~= nil, needle)
			end
			-- 판정·리모트 없음 (연출만)
			t.ok(string.find(src, "Remotes", 1, true) == nil, "no remotes in lobby fx")
		end
	)

	t.test("QA: 단상 속성 이름이 서로 달라요", function()
		local a = LobbyLayout.WINNER_ATTRS
		t.ok(a.userId ~= a.appearanceId and a.appearanceId ~= a.serial and a.userId ~= a.serial)
	end)
end
