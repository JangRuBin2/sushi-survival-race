--!strict
-- 인형 물고기 움직임 (m5-32, 클라이언트 로컬 연출). 탈락·우승 인형, 로비 단상, 탈의실·뽑기 화면 미리보기처럼
-- SushiBody.build로 만든 인형에서 고등어 관절(FishRig — 관절 이름으로만 찾아요)을 팔딱이게 해요.
--   DollAnimator.attach(model, mode, opts?) -> () -> ()   멈추기 함수 (Cleanup에 넣어도 돼요). 고등어 관절이 없으면
--                                                          아무것도 안 하고 빈 함수를 돌려줘요 (다른 스킨 인형은 지금처럼 정지).
--     mode: "Hurt"(탈락 — 축 처짐 + 가끔 경련) · "Victory"(우승·단상 — 신나게 자주 팔딱) · "Preview"(탈의실·뽑기 — 살랑 + 자주)
--     opts.sound: "World"(인형 위치 3D) · "Ui"(화면 소리, 작게) · nil(소리 없음)
-- 인형은 고정(Anchored)이거나 ViewportFrame 안이라 Motor6D가 풀리지 않아요 → 고등어 쪽 파츠를 고정하고 CFrame을 직접
-- 써요(Body 기준 쉰 자리 · 관절 사슬 움직임). 연출이 인형을 PivotTo·ScaleTo로 옮기거나 키워도 Body를 따라가요.
-- 화면에 보일 때만 돌려요: ViewportFrame 안이면 그 화면(ScreenGui·Frame)이 보일 때, 월드면 카메라에서 DETAIL_DISTANCE 안.
-- 인형이 지워지면(부모 nil) 저절로 빠지고, 프레임 연결은 인형이 하나라도 있을 때만 하나.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CharacterAnimLogic = require(ReplicatedStorage.Shared.CharacterAnimLogic)
local Sfx = require(script.Parent.Parent.Sfx)
local FishRig = require(script.Parent.FishRig)

local DollAnimator = {}

export type Mode = "Hurt" | "Victory" | "Preview"
export type Options = { sound: ("World" | "Ui")? }

DollAnimator.UI_VOLUME = 0.4 -- 탈의실·뽑기 화면 인형 소리 배율

type Driven = { part: BasePart, joint: string, rel: CFrame }

type Doll = {
	model: Model,
	body: BasePart,
	rig: FishRig.Rig,
	driven: { Driven },
	scale0: number,
	mode: Mode,
	sound: ("World" | "Ui")?,
	clock: number,
	flopWait: number,
	flopTime: number?,
	soundAt: { [string]: number }, -- 소리 이름 → 마지막으로 울린 시각
	alive: boolean,
}

local dolls: { Doll } = {}
local connection: RBXScriptConnection? = nil

-- 이 파츠가 따라가는 고등어 관절 이름 (용접·관절을 Body 쪽으로 거슬러 올라가요). 없으면 nil
local function jointOf(part: BasePart, rig: FishRig.Rig, body: BasePart): string?
	local current: BasePart? = part
	for _ = 1, 16 do
		if current == nil or current == body then
			return nil
		end
		local here = current :: BasePart
		if rig.byName[here.Name] and rig.byName[here.Name].part == here then
			return here.Name
		end
		local anchor: BasePart? = nil
		for _, child in here:GetChildren() do
			local isJoint = child:IsA("WeldConstraint") or child:IsA("Motor6D")
			if isJoint and (child :: any).Part1 == here then
				anchor = (child :: any).Part0
			end
		end
		current = anchor
	end
	return nil
end

local function scaleOf(model: Model): number
	local ok, value = pcall(function()
		return model:GetScale()
	end)
	return if ok and type(value) == "number" and value > 0 then value else 1
end

local function shown(doll: Doll): boolean
	if doll.model:FindFirstAncestorOfClass("DataModel") == nil then
		return false
	end
	local viewport = doll.model:FindFirstAncestorWhichIsA("ViewportFrame")
	if viewport then
		local node: Instance? = viewport
		while node do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			elseif node:IsA("LayerCollector") then
				return node.Enabled
			end
			node = node.Parent
		end
		return false
	end
	local camera = Workspace.CurrentCamera
	return camera == nil
		or (camera.CFrame.Position - doll.body.CFrame.Position).Magnitude <= CharacterAnimLogic.DETAIL_DISTANCE
end

local function play(doll: Doll, cues: { string })
	local kind = doll.sound
	if kind == nil then
		return
	end
	for _, cue in CharacterAnimLogic.fishSoundFilter(doll.soundAt, cues, os.clock()) do
		if kind == "World" then
			Sfx.play(cue, doll.body)
		else
			Sfx.play(cue, nil, DollAnimator.UI_VOLUME)
		end
	end
end

local function step(doll: Doll, dt: number)
	doll.clock += dt
	local flopTime = doll.flopTime
	local duration = CharacterAnimLogic.flopDuration(doll.mode)
	if flopTime ~= nil then
		local nextTime = flopTime + dt
		play(doll, CharacterAnimLogic.fishCues("Flop", doll.mode, flopTime, nextTime))
		doll.flopTime = if nextTime < duration then nextTime else nil
	else
		doll.flopWait -= dt
		if doll.flopWait <= 0 then
			doll.flopTime = 0
			doll.flopWait = CharacterAnimLogic.nextFlopDelay(math.random(), doll.mode)
			play(doll, CharacterAnimLogic.fishCues("Flop", doll.mode, nil, 0))
		end
	end
	local pose = CharacterAnimLogic.fishPose({
		time = doll.clock,
		walk = 0,
		phase = 0,
		riseSpeed = 0,
		airborne = false,
		landTime = nil,
		landStrength = 0,
		knocked = false,
		flopTime = doll.flopTime,
		mode = doll.mode,
	})
	local scale = scaleOf(doll.model)
	local deltas = FishRig.deltas(doll.rig, CharacterAnimLogic.fishMotion(pose), scale)
	-- 관절 사슬: 부모 움직임 · 자기 움직임 (FISH_JOINTS 순서라 부모가 먼저)
	local chain: { [string]: CFrame } = {}
	for _, joint in doll.rig.joints do
		local parent = if joint.parent then chain[joint.parent] else nil
		chain[joint.name] = (parent or CFrame.identity) * deltas[joint.name]
	end
	local bodyCf = doll.body.CFrame
	local k = scale / doll.scale0
	for _, item in doll.driven do
		local rel = item.rel
		local relNow = if k == 1 then rel else rel - rel.Position + rel.Position * k
		item.part.CFrame = bodyCf * (chain[item.joint] or CFrame.identity) * relNow
	end
end

local function frame(dt: number)
	for i = #dolls, 1, -1 do
		local doll = dolls[i]
		-- 지워진 인형(부모 없음)은 빼요. 아직 게임 밖(연출이 곧 붙일 Model 안)이면 기다려요
		if not doll.alive or doll.model.Parent == nil then
			doll.alive = false
			table.remove(dolls, i)
		elseif shown(doll) then
			step(doll, dt)
		end
	end
	if #dolls == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

function DollAnimator.attach(model: Model, mode: Mode, opts: Options?): () -> ()
	local rig = FishRig.find(model)
	local body = model.PrimaryPart or (rig and rig.body)
	if rig == nil or body == nil then
		return function() end
	end
	local driven: { Driven } = {}
	local bodyCf = body.CFrame
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item ~= body then
			local joint = jointOf(item, rig, body)
			if joint then
				table.insert(driven, { part = item, joint = joint, rel = bodyCf:ToObjectSpace(item.CFrame) })
			end
		end
	end
	-- 관절·용접 대신 CFrame을 직접 써요 (인형은 보이기만). 움직이는 파츠를 붙잡던 용접·Motor6D는 끊어요:
	-- 용접이 남아 있으면 CFrame을 쓸 때 같은 덩어리(밥·얼굴·팔다리)까지 끌려가거나 떨릴 수 있어요 (QA 위험).
	-- 모든 파츠를 다 찾은 뒤에 끊어요(jointOf가 용접을 따라 올라가요). Body와 나머지 파츠의 용접은 그대로예요
	for _, item in driven do
		item.part.Anchored = true
		for _, child in item.part:GetChildren() do
			if (child:IsA("WeldConstraint") or child:IsA("Motor6D")) and (child :: any).Part1 == item.part then
				(child :: any).Enabled = false
			end
		end
	end
	local doll: Doll = {
		model = model,
		body = body,
		rig = rig,
		driven = driven,
		scale0 = scaleOf(model),
		mode = mode,
		sound = opts and opts.sound,
		clock = math.random() * 10,
		-- 처음 팔딱은 조금 빨리 (화면을 열자마자 보이게)
		flopWait = 0.4 + math.random() * 0.6,
		flopTime = nil,
		soundAt = {},
		alive = true,
	}
	table.insert(dolls, doll)
	if connection == nil then
		connection = RunService.RenderStepped:Connect(frame)
	end
	return function()
		doll.alive = false
	end
end

return DollAnimator
