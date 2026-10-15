--!strict
-- m5-40 L3 QA (docs/qa/m5-40-l3.md): bouncy-castle-maze · lantern-bridge 길이 늘리기 회귀 테스트.
--   1. 판정 파츠 하나하나 고정: c121dda(m5-40 전)의 판정 파츠(이름·크기·origin 기준 위치·충돌/터치/쿼리·태그·
--      BridgeIndex·모양) 중 이 스펙이 옮기거나 늘린 8개를 뺀 64개가 그대로 있고, 그 8개는 의도한 새 값이에요.
--      (m5-24-qa 판정 지문은 합계라 새 값으로 바꾸면 옛 파츠가 같이 바뀌어도 모를 수 있어서 파츠별로 다시 봐요)
--   2. 방방 미로: 새 기둥·두 번째 미로 문/칸막이 윗면 = 벽 높이(14) — 바운스 여유가 첫 미로와 같아요.
--      최악 발 높이(레이캐스트 끝에서 튕김 + 공중 다이브)를 기록하고 더 나빠지지 않게 막아요(리포트 B1, P2).
--   3. 등불 다리: 개울 발판 틈 + 착지 여유가 실제 점프 수평 거리 안, 다리 폭 <= 이웃 평지 폭, 흔들림으로
--      다리 가장자리가 이웃 평지보다 솟는 높이 <= 1.
--   4. 배경(물·잔디)이 두 맵 모두 낙하선보다 10 이상 아래이고 늘어난 코스 전체를 덮어요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local MapKitLogic = RobloxRequire.require(Shared.maps.MapKitLogic)
local MazeLayout = RobloxRequire.require(Shared.maps.BouncyCastleMazeLayout)
local MazeLogic = RobloxRequire.require(Shared.maps.BouncyCastleMazeLogic)
local MazeArt = RobloxRequire.require(Shared.maps.BouncyCastleMazeArt)
local BridgeLayout = RobloxRequire.require(Shared.maps.LanternBridgeLayout)
local BridgeLogic = RobloxRequire.require(Shared.maps.LanternBridgeLogic)
local BridgeArt = RobloxRequire.require(Shared.maps.LanternBridgeArt)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local GRAVITY = 196.2
local STAND_ROOT_Y = 3 -- 서 있을 때 바닥 기준 루트 높이 (m5-14-qa와 같음)

-- c121dda에서 같은 형식으로 뽑은 판정 파츠 중 m5-40이 건드리지 않아야 하는 것 (64개)
local KEPT_ROWS = {
	"bouncy-castle-maze|ExitWallLeft|30.00,14.00,2.00|-5.00,7.00,-110.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|FloorBounce|40.00,2.00,94.00|0.00,-1.00,-63.00|ctrue ttrue qtrue|BounceFloor|nil|Enum.PartType.Block",
	"bouncy-castle-maze|FloorExit|40.00,2.00,10.00|0.00,-1.00,-115.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|FloorStart|40.00,2.00,16.00|0.00,-1.00,-8.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|GateDoorRight|30.00,14.00,2.00|5.00,7.00,-20.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Partition1|1.00,14.00,80.00|-10.00,7.00,-60.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Partition2|1.00,14.00,80.00|0.00,7.00,-70.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Partition3|1.00,14.00,80.00|10.00,7.00,-60.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn01|2.00,0.20,2.00|-15.00,0.10,-2.50|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn02|2.00,0.20,2.00|-9.00,0.10,-2.50|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn03|2.00,0.20,2.00|-3.00,0.10,-2.50|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn04|2.00,0.20,2.00|3.00,0.10,-2.50|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn05|2.00,0.20,2.00|9.00,0.10,-2.50|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn06|2.00,0.20,2.00|15.00,0.10,-2.50|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn07|2.00,0.20,2.00|-15.00,0.10,-6.10|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn08|2.00,0.20,2.00|-9.00,0.10,-6.10|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn09|2.00,0.20,2.00|-3.00,0.10,-6.10|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn10|2.00,0.20,2.00|3.00,0.10,-6.10|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn11|2.00,0.20,2.00|9.00,0.10,-6.10|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn12|2.00,0.20,2.00|15.00,0.10,-6.10|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn13|2.00,0.20,2.00|-15.00,0.10,-9.70|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn14|2.00,0.20,2.00|-9.00,0.10,-9.70|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn15|2.00,0.20,2.00|-3.00,0.10,-9.70|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn16|2.00,0.20,2.00|3.00,0.10,-9.70|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn17|2.00,0.20,2.00|9.00,0.10,-9.70|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn18|2.00,0.20,2.00|15.00,0.10,-9.70|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn19|2.00,0.20,2.00|-15.00,0.10,-13.30|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn20|2.00,0.20,2.00|-9.00,0.10,-13.30|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn21|2.00,0.20,2.00|-3.00,0.10,-13.30|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn22|2.00,0.20,2.00|3.00,0.10,-13.30|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn23|2.00,0.20,2.00|9.00,0.10,-13.30|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Spawns.Spawn24|2.00,0.20,2.00|15.00,0.10,-13.30|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|StartWall|41.00,14.00,0.50|0.00,7.00,0.25|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"lantern-bridge|Plank1|8.00,2.00,20.00|0.00,-1.00,-24.00|ctrue ttrue qtrue|LanternBridgePlank|1|Enum.PartType.Block",
	"lantern-bridge|Plank2|6.00,2.00,24.00|0.00,-1.00,-56.00|ctrue ttrue qtrue|LanternBridgePlank|2|Enum.PartType.Block",
	"lantern-bridge|Plank3|4.00,2.00,20.00|0.00,-1.00,-88.00|ctrue ttrue qtrue|LanternBridgePlank|3|Enum.PartType.Block",
	"lantern-bridge|Rest1Floor|10.00,2.00,10.00|0.00,-1.00,-39.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"lantern-bridge|Rest2Floor|10.00,2.00,10.00|0.00,-1.00,-73.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"lantern-bridge|Rest3Floor|10.00,2.00,10.00|0.00,-1.00,-103.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn01|2.00,0.20,2.00|-6.00,0.10,-1.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn02|2.00,0.20,2.00|-3.00,0.10,-1.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn03|2.00,0.20,2.00|0.00,0.10,-1.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn04|2.00,0.20,2.00|3.00,0.10,-1.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn05|2.00,0.20,2.00|6.00,0.10,-1.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn06|2.00,0.20,2.00|-6.00,0.10,-4.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn07|2.00,0.20,2.00|-3.00,0.10,-4.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn08|2.00,0.20,2.00|0.00,0.10,-4.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn09|2.00,0.20,2.00|3.00,0.10,-4.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn10|2.00,0.20,2.00|6.00,0.10,-4.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn11|2.00,0.20,2.00|-6.00,0.10,-7.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn12|2.00,0.20,2.00|-3.00,0.10,-7.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn13|2.00,0.20,2.00|0.00,0.10,-7.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn14|2.00,0.20,2.00|3.00,0.10,-7.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn15|2.00,0.20,2.00|6.00,0.10,-7.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn16|2.00,0.20,2.00|-6.00,0.10,-10.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn17|2.00,0.20,2.00|-3.00,0.10,-10.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn18|2.00,0.20,2.00|0.00,0.10,-10.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn19|2.00,0.20,2.00|3.00,0.10,-10.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn20|2.00,0.20,2.00|6.00,0.10,-10.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn21|2.00,0.20,2.00|-6.00,0.10,-13.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn22|2.00,0.20,2.00|-3.00,0.10,-13.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn23|2.00,0.20,2.00|0.00,0.10,-13.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Spawns.Spawn24|2.00,0.20,2.00|3.00,0.10,-13.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|StartFloor|16.00,2.00,14.00|0.00,-1.00,-7.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
}

-- m5-40이 의도해서 옮기거나 늘린 옛 파츠 8개의 새 값 (전 값은 리포트 AC6 표)
local MOVED_ROWS = {
	"bouncy-castle-maze|EndWall|41.00,14.00,0.50|0.00,7.00,-246.25|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|FinishLine|40.00,0.40,1.00|0.00,0.20,-240.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"bouncy-castle-maze|FloorFinish|40.00,2.00,20.00|0.00,-1.00,-236.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Wall|0.50,14.00,246.00|-20.25,7.00,-123.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"bouncy-castle-maze|Wall|0.50,14.00,246.00|20.25,7.00,-123.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"lantern-bridge|FinishFloor|16.00,2.00,14.00|0.00,-1.00,-375.00|ctrue ttrue qtrue||nil|Enum.PartType.Block",
	"lantern-bridge|FinishLine|16.00,0.40,1.00|0.00,0.20,-378.00|cfalse tfalse qfalse||nil|Enum.PartType.Block",
	"lantern-bridge|Plank4|8.00,2.00,30.00|0.00,-1.00,-353.00|ctrue ttrue qtrue|LanternBridgePlank|4|Enum.PartType.Block",
}

local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)
local built: { [string]: any } = {}
local function build(id: string): any
	if built[id] == nil then
		built[id] = RMaps.get(id).build(origin)
	end
	return built[id]
end

local function under(inst: any, root: any, name: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

local function rowsOf(id: string): { [string]: boolean }
	local model = build(id)
	local rows: { [string]: boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not under(d, model, "Decor") and not under(d, model, "IntroCamera") then
			local p = origin:PointToObjectSpace(d.CFrame.Position)
			local tags = d:GetTags()
			table.sort(tags)
			local name = (string.gsub(d:GetFullName(), "^.-%.", ""))
			local row = string.format(
				"%s|%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|c%s t%s q%s|%s|%s|%s",
				id,
				name,
				d.Size.X,
				d.Size.Y,
				d.Size.Z,
				p.X,
				p.Y,
				p.Z,
				tostring(d.CanCollide),
				tostring(d.CanTouch),
				tostring(d.CanQuery),
				table.concat(tags, ","),
				tostring(d:GetAttribute("BridgeIndex")),
				tostring(d.Shape)
			)
			rows[row] = true
		end
	end
	return rows
end

-- 서버가 BOUNCE_HOLD초 동안 위 속도를 고정한 뒤 놓는 실제 상승량 (m5-14-qa realBounce와 같은 계산)
local function realRise(): number
	local v = MazeLayout.BOUNCE_UP_SPEED
	return v * MazeLayout.BOUNCE_HOLD + MazeLogic.bounceProfile(v, GRAVITY).apex
end

return function(t: Test.Test)
	t.test("L3 QA: c121dda 판정 파츠 64개가 그대로, 옮긴 8개는 의도한 새 값이에요", function()
		local rows = {
			["bouncy-castle-maze"] = rowsOf("bouncy-castle-maze"),
			["lantern-bridge"] = rowsOf("lantern-bridge"),
		}
		t.eq(#KEPT_ROWS, 64)
		t.eq(#MOVED_ROWS, 8)
		for _, list in { KEPT_ROWS, MOVED_ROWS } do
			for _, row in list do
				local id = string.match(row, "^([^|]+)") :: string
				t.ok(rows[id][row] == true, `missing or changed: {row}`)
			end
		end
		-- 파츠 수(FinishLine·Spawns 포함): 방방 미로 38 → 73 (바닥 3·문 2·칸막이 2·기둥 28), 등불 다리 34 → 52 (판자 3·쉼터 2·개울 평지 3·돌 10)
		local counts = { ["bouncy-castle-maze"] = 0, ["lantern-bridge"] = 0 }
		for id, set in rows do
			for _ in set do
				counts[id] += 1
			end
		end
		t.eq(counts["bouncy-castle-maze"], 73)
		t.eq(counts["lantern-bridge"], 52)
	end)

	t.test(
		"L3 QA 방방 미로: 새 기둥·문·칸막이 윗면이 벽 윗면과 같아요 (바운스 여유가 첫 미로와 같음)",
		function()
			local model = build("bouncy-castle-maze")
			local wallTop: number? = nil
			local checked = 0
			for _, d in model:GetChildren() do
				if d:IsA("BasePart") then
					local p = origin:PointToObjectSpace(d.CFrame.Position)
					local isPillar = string.match(d.Name, "^BalloonPillar") ~= nil
					local height = if isPillar then d.Size.X else d.Size.Y
					local top = p.Y + height / 2
					if d.Name == "Wall" then
						wallTop = top
					elseif isPillar or string.match(d.Name, "^Maze2") then
						checked += 1
						t.ok(math.abs(top - MazeLayout.WALL_HEIGHT) < 1e-4, `{d.Name} top {top}`)
					end
				end
			end
			t.eq(wallTop, MazeLayout.WALL_HEIGHT)
			t.eq(checked, 28 + 4)
		end
	)

	t.test(
		"L3 QA 방방 미로 B1(P2, 기존): 레이캐스트 끝(루트 4.5)에서 튕기면 발 최고점 + 다이브가 벽 14에 닿아요 — 더 나빠지면 안 돼요",
		function()
			local diveExtra = Config.Dive.AirMaxUpSpeed ^ 2 / (2 * GRAVITY)
			local fromFloor = realRise() + diveExtra
			local triggerFeet = MazeLayout.BOUNCE_RAYCAST_LENGTH - STAND_ROOT_Y
			local worst = triggerFeet + fromFloor
			-- 바닥에서 튕길 때는 여유가 있어요 (m5-14-qa와 같음)
			t.ok(fromFloor < MazeLayout.WALL_HEIGHT - 1, `from floor {fromFloor}`)
			-- 지금 최악값 약 14.25 (벽보다 0.25 높음). 수치를 바꿔 이보다 커지면 실패해요 — 고치면 WALL_HEIGHT 아래로 내려요
			t.ok(worst < 14.3, `worst feet apex {worst} vs wall {MazeLayout.WALL_HEIGHT}`)
		end
	)

	t.test(
		"L3 QA 등불 다리 개울: 발판 사이 틈 + 착지 여유 1이 실제 점프 수평 거리의 75% 안이에요",
		function()
			local reach = Config.Character.WalkSpeed * (2 * Config.Character.JumpPower / GRAVITY)
			local pads = BridgeLayout.streamPads()
			local worst = 0
			for i = 2, #pads do
				worst = math.max(worst, BridgeLogic.padGap(pads[i - 1], pads[i]))
			end
			t.ok(worst + 1 <= reach * 0.75, `worst gap {worst} + 1 vs 75% of jump reach {reach}`)
			-- 돌은 섬 폭 안쪽에 있어요 (개울 가운데 줄에서 크게 벗어나지 않음)
			for _, stone in BridgeLayout.STONES do
				t.ok(math.abs(stone.x) + stone.radius <= BridgeLayout.STREAM_ISLAND.width / 2, stone.name)
			end
		end
	)

	t.test("L3 QA 등불 다리: 다리 폭 <= 앞뒤 평지 폭, 흔들려 솟는 가장자리 <= 1", function()
		local floors: { { front: number, back: number, width: number } } = {
			{ front = BridgeLayout.START.front, back = BridgeLayout.START.back, width = BridgeLayout.START_WIDTH },
			{ front = BridgeLayout.FINISH.front, back = BridgeLayout.FINISH.back, width = BridgeLayout.FINISH_WIDTH },
			BridgeLayout.STREAM_BANK_FRONT,
			BridgeLayout.STREAM_BANK_BACK,
		}
		for _, rest in BridgeLayout.RESTS do
			table.insert(floors, rest)
		end
		for _, bridge in BridgeLayout.BRIDGES do
			local before, after = nil, nil
			for _, f in floors do
				if f.back == bridge.front then
					before = f
				end
				if f.front == bridge.back then
					after = f
				end
			end
			t.ok(before ~= nil and after ~= nil, `bridge {bridge.index} has floors on both ends`)
			if before and after then
				t.ok(bridge.width <= before.width and bridge.width <= after.width, `bridge {bridge.index} width`)
			end
			local lip = bridge.halfWidth * math.sin(math.rad(bridge.maxSwayDeg))
			t.ok(lip <= 1, `bridge {bridge.index} edge lip {lip}`)
		end
	end)

	t.test(
		"L3 QA: 두 맵 배경이 낙하선보다 10 이상 아래이고 늘어난 코스 전체를 덮어요",
		function()
			local cases = {
				{
					decor = BridgeArt.decor(),
					name = "RiverWater",
					fall = BridgeLogic.fallLineAt(BridgeLayout.FINISH.back),
					front = BridgeLayout.START.front,
					back = BridgeLayout.FINISH.back,
				},
				{
					decor = MazeArt.decor(),
					name = "ParkGrass",
					fall = MazeLogic.fallLineAt(MazeLayout.FINISH.back),
					front = MazeLayout.START.front,
					back = MazeLayout.FINISH.back,
				},
			}
			for _, c in cases do
				local found = false
				for _, spec in c.decor do
					if spec.name == c.name then
						found = true
						local b = MapKitLogic.bounds({ spec }) :: any
						t.ok(b.max.y <= c.fall - 10, `{c.name} top {b.max.y} vs fall line {c.fall}`)
						t.ok(b.max.z >= c.front + 40 and b.min.z <= c.back - 40, `{c.name} covers course z`)
					end
				end
				t.ok(found, c.name)
			end
		end
	)
end
