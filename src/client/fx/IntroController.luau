--!strict
-- 라운드 소개 플라이스루와 "출발!" (m3-04, GDD 4-2·4-3·11.3).
--   RoundIntro: 내가 이번 라운드를 뛰면(aliveUserIds에 있으면) 내 방 맵(Attributes.RoomId/RoundIndex)을
--               최대 1초 찾아서, 소개 시간의 앞 80%는 경로 비행, 뒤 20%는 내 캐릭터 뒤로 붙어요.
--               경로는 맵의 IntroCamera 폴더(파츠 이름순) → 없으면 IntroCameraLogic.autoPath.
--               관전자(이미 탈락)는 보지 않아요 (관전 화면 그대로).
--   RoundActive: 카메라를 돌려주고, 플라이스루 대상이었으면 "출발!" + Sfx "Go".
--   새 RoundIntro가 오면 처음부터, 방을 나가거나 다른 단계가 되면 바로 정리해요.
-- 카메라는 CameraDirector("Intro", Priority.Intro)로 요청하고, 매 프레임 움직이는 건
-- CameraDirector.isActive("Intro")일 때만이에요 (더 높은 탈락 연출이 가져갈 수 있어요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local IntroCameraLogic = require(ReplicatedStorage.Shared.IntroCameraLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Sfx = require(script.Parent.Parent.Sfx)
local IntroScreen = require(script.Parent.IntroScreen)

local OWNER = "Intro"
local RENDER_STEP = "IntroFlythrough"
local FLIGHT_FRACTION = 0.8 -- 3초 중 2.4초 비행, 0.6초 캐릭터 뒤로 복귀
local MAP_WAIT = 1 -- 서버가 소개 방송 직후 맵을 지어요. 이만큼 못 찾으면 이번 플라이스루는 건너뛰어요.
local MIN_FLIGHT = 0.6 -- 맵을 늦게 찾아도 비행은 최소 이만큼
local HOLD_TIMEOUT = 2 -- 복귀가 끝나고 RoundActive가 이만큼 안 오면 카메라를 돌려줘요
local GO_DURATION = 0.8
local INTRO_FOLDER = "IntroCamera"
-- 기본 카메라와 비슷한 "캐릭터 뒤" 위치 (HumanoidRootPart 기준: 위로, 뒤로)
local FOLLOW_OFFSET = Vector3.new(0, 4, 12)
local FOLLOW_FOCUS = Vector3.new(0, 1.5, 0)
local FALLBACK_FORWARD = Vector3.new(0, 0, -1)

type Waypoint = IntroCameraLogic.Waypoint

local IntroController = {}

local function toVec(v: Vector3): IntroCameraLogic.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function toVector3(v: IntroCameraLogic.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function waypointCFrame(waypoint: Waypoint): CFrame
	return CFrame.lookAt(toVector3(waypoint.position), toVector3(waypoint.lookAt))
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- 방 id·라운드 번호가 맞는 맵 Model (없으면 nil)
local function findMap(roomId: string, roundIndex: number): Model?
	for _, child in workspace:GetChildren() do
		if
			child:IsA("Model")
			and child:GetAttribute(Attributes.RoomId) == roomId
			and child:GetAttribute(Attributes.RoundIndex) == roundIndex
		then
			return child
		end
	end
	return nil
end

-- 보이는 파츠로 월드 축 경계 상자를 재요 (투명한 판정 구역·스폰은 빼요)
local function boundsOf(model: Model): IntroCameraLogic.Bounds
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	local found = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local cf, half = part.CFrame, part.Size / 2
			-- 회전한 파츠의 축 정렬 반지름: |R| * half
			local extent = Vector3.new(
				math.abs(cf.RightVector.X) * half.X
					+ math.abs(cf.UpVector.X) * half.Y
					+ math.abs(cf.LookVector.X) * half.Z,
				math.abs(cf.RightVector.Y) * half.X
					+ math.abs(cf.UpVector.Y) * half.Y
					+ math.abs(cf.LookVector.Y) * half.Z,
				math.abs(cf.RightVector.Z) * half.X
					+ math.abs(cf.UpVector.Z) * half.Y
					+ math.abs(cf.LookVector.Z) * half.Z
			)
			minV = minV:Min(cf.Position - extent)
			maxV = maxV:Max(cf.Position + extent)
			found = true
		end
	end
	if not found then
		local cf, size = model:GetBoundingBox()
		return { center = toVec(cf.Position), size = toVec(size) }
	end
	return { center = toVec((minV + maxV) / 2), size = toVec(maxV - minV) }
end

-- 출발 지점과 코스 방향. 스폰 파츠는 맵 origin과 같은 방향으로 놓여요 (MapTypes: 코스는 LookVector 쪽).
-- Survival·Final은 내 캐릭터가 이미 맵 위에 있으면 내 쪽에서 끝나게 내 위치를 써요.
local function originOf(model: Model, bounds: IntroCameraLogic.Bounds, kind: Types.MapKind): IntroCameraLogic.Origin
	local spawnsFolder = model:FindFirstChild("Spawns")
	local spawns: { BasePart } = {}
	if spawnsFolder then
		for _, child in spawnsFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawns, child)
			end
		end
	end
	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)

	local center = toVector3(bounds.center)
	local position = center - Vector3.new(0, bounds.size.y / 2, 0)
	local forward = FALLBACK_FORWARD
	if #spawns > 0 then
		local sum = Vector3.zero
		for _, spawn in spawns do
			sum += spawn.Position
		end
		position = sum / #spawns
		forward = spawns[1].CFrame.LookVector
	end

	if kind ~= "Race" then
		local root = rootOf(Players.LocalPlayer)
		local half = toVector3(bounds.size) / 2
		if root then
			local offset = root.Position - center
			if math.abs(offset.X) <= half.X and math.abs(offset.Z) <= half.Z then
				position = root.Position
			end
		end
	end
	return { position = toVec(position), forward = toVec(forward) }
end

local function pathOf(model: Model, kind: Types.MapKind): { Waypoint }
	local folder = model:FindFirstChild(INTRO_FOLDER)
	if folder then
		local parts: { BasePart } = {}
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		table.sort(parts, function(a, b)
			return a.Name < b.Name
		end)
		if #parts > 0 then
			local path: { Waypoint } = {}
			for _, part in parts do
				local look = part.Position + part.CFrame.LookVector * 20
				table.insert(path, { position = toVec(part.Position), lookAt = toVec(look) })
			end
			return path
		end
	end
	local bounds = boundsOf(model)
	return IntroCameraLogic.autoPath(bounds, originOf(model, bounds, kind), kind)
end

-- 기본 카메라가 이어받기 좋은 내 캐릭터 뒤 위치 (캐릭터가 없으면 nil)
local function followCFrame(): CFrame?
	local root = rootOf(Players.LocalPlayer)
	if root == nil then
		return nil
	end
	local position = root.CFrame:PointToWorldSpace(FOLLOW_OFFSET)
	return CFrame.lookAt(position, root.Position + FOLLOW_FOCUS)
end

function IntroController.start(gui: Instance)
	local me = Players.LocalPlayer.UserId
	local screen = IntroScreen.new(gui)

	local roomId: string? = nil
	local inMatch = false
	local aliveUserIds: { number }? = nil
	local participant = false -- 이번 라운드 소개를 본 사람 ("출발!" 대상)
	local token = 0

	local function stopIntro()
		token += 1
		RunService:UnbindFromRenderStep(RENDER_STEP)
		CameraDirector.release(OWNER)
	end

	local function beginIntro(info: Types.MatchPhaseInfo, myRoomId: string, roundIndex: number)
		stopIntro()
		local mine = token
		local introStart = os.clock()
		local total = Config.Match.IntroDuration
		if info.endsAt then
			total = math.clamp(info.endsAt - workspace:GetServerTimeNow(), MIN_FLIGHT, Config.Match.IntroDuration)
		end
		local kind: Types.MapKind = info.mapKind or "Race"

		task.spawn(function()
			local model = findMap(myRoomId, roundIndex)
			while model == nil and token == mine and os.clock() - introStart < MAP_WAIT do
				task.wait()
				model = findMap(myRoomId, roundIndex)
			end
			if model == nil or token ~= mine then
				return -- 맵을 못 찾았으면 배너만 (M2와 같음)
			end

			local ok, pathOrErr = pcall(pathOf, model, kind)
			if not ok then
				warn(`[IntroController] flythrough path failed: {pathOrErr}`)
				return
			end
			local path = pathOrErr :: { Waypoint }
			if #path == 0 then
				return
			end
			local endCFrame = waypointCFrame(path[#path])

			local flightStart = os.clock()
			local flightEnd = math.max(introStart + total * FLIGHT_FRACTION, flightStart + MIN_FLIGHT)
			local flightDuration = flightEnd - flightStart
			local blendDuration = total * (1 - FLIGHT_FRACTION)
			local holdUntil = flightEnd + blendDuration + HOLD_TIMEOUT

			local function frame(): CFrame
				local now = os.clock()
				if now < flightEnd then
					return waypointCFrame(IntroCameraLogic.sample(path, (now - flightStart) / flightDuration))
				end
				local follow = followCFrame()
				if follow == nil then
					return endCFrame
				end
				local alpha = IntroCameraLogic.ease((now - flightEnd) / blendDuration)
				return endCFrame:Lerp(follow, alpha)
			end

			Sfx.play("IntroWhoosh")
			CameraDirector.request(OWNER, CameraDirector.Priority.Intro, function(camera: Camera)
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = frame()
			end)
			RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function()
				if token ~= mine then
					return
				end
				if os.clock() > holdUntil then
					stopIntro() -- RoundActive를 못 받았어요: 카메라를 돌려줘요
					return
				end
				if not CameraDirector.isActive(OWNER) then
					return -- 더 높은 연출이 카메라를 쓰는 중
				end
				local camera = workspace.CurrentCamera
				if camera then
					if camera.CameraType ~= Enum.CameraType.Scriptable then
						camera.CameraType = Enum.CameraType.Scriptable
					end
					camera.CFrame = frame()
				end
			end)
		end)
	end

	local function isAlive(): boolean
		local alive = aliveUserIds
		return alive ~= nil and table.find(alive, me) ~= nil
	end

	Remotes.event("RoomUpdated").OnClientEvent:Connect(function(room: Types.RoomSnapshot?)
		roomId = if room then room.id else nil
		local nowInMatch = room ~= nil and room.state == "InMatch"
		if not nowInMatch then
			inMatch = false
			participant = false
			aliveUserIds = nil
			stopIntro()
			screen:hide()
		else
			inMatch = true
		end
	end)

	Remotes.event("MatchPhase").OnClientEvent:Connect(function(info: Types.MatchPhaseInfo)
		if info.aliveUserIds then
			aliveUserIds = info.aliveUserIds
		end

		if info.phase == "RoundIntro" then
			screen:hide()
			participant = inMatch and roomId ~= nil and isAlive()
			local myRoomId, roundIndex = roomId, info.roundIndex
			if participant and myRoomId and roundIndex then
				beginIntro(info, myRoomId, roundIndex)
			else
				stopIntro()
			end
		elseif info.phase == "RoundActive" then
			stopIntro()
			if participant then
				participant = false
				screen:showGo(GO_DURATION)
				Sfx.play("Go")
			end
		else
			participant = false
			stopIntro()
		end
	end)
end

return IntroController
