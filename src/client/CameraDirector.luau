--!strict
-- 카메라 중재. 관전·라운드 소개·탈락 연출·우승 연출이 카메라를 동시에 잡으려 할 때
-- 우선순위가 가장 높은 요청의 apply만 카메라에 반영해요 (고르는 규칙은 Shared.CameraPriority).
--
--   CameraDirector.request(owner, priority, apply)
--       카메라를 쓰겠다고 요청해요. 이 owner가 지금 1등이면 apply(camera)를 바로 불러요.
--       이미 요청 중인 owner가 다시 부르면 우선순위·apply를 바꾸고(순서는 처음 요청 그대로),
--       1등이면 apply를 다시 불러요 — 기본 카메라 스크립트가 CameraSubject를 되돌린 걸 다시 맞출 때 써요.
--   CameraDirector.release(owner)
--       요청을 거둬요. 1등이 바뀌면 다음 owner의 apply를 다시 부르고, 아무도 없으면 기본 카메라
--       (CameraType = Custom, CameraSubject = 내 Humanoid)로 돌려요. 요청하지 않은 owner면 아무것도 안 해요.
--   CameraDirector.current()   지금 카메라를 쓰는 owner (없으면 nil)
--   CameraDirector.isActive(owner)
--
-- apply는 카메라를 한 번 맞추는 함수예요. 매 프레임 움직이는 연출은 자기 RenderStepped 안에서
-- CameraDirector.isActive(owner)일 때만 카메라를 움직여요 (더 높은 요청에 밀렸을 수 있어요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraPriority = require(ReplicatedStorage.Shared.CameraPriority)

type Entry = {
	owner: string,
	priority: number,
	apply: (camera: Camera) -> (),
}

local CameraDirector = {}

CameraDirector.Priority = {
	Spectate = 10,
	Victory = 20, -- 우승 단계에 로비의 우승자 비추기 (SpectateController)
	Intro = 30,
	Elimination = 40,
	VictoryCutscene = 50,
}

local entries: { Entry } = {} -- 처음 요청한 순서대로
local currentOwner: string? = nil

local function indexOf(owner: string): number?
	for i, entry in entries do
		if entry.owner == owner then
			return i
		end
	end
	return nil
end

local function applyDefault(camera: Camera)
	camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function runApply(entry: Entry, camera: Camera)
	local ok, err = pcall(entry.apply, camera)
	if not ok then
		warn(`[CameraDirector] {entry.owner} apply failed: {err}`)
	end
end

local function pickOwner(): string?
	local requests: { CameraPriority.Request } = {}
	for _, entry in entries do
		table.insert(requests, { owner = entry.owner, priority = entry.priority })
	end
	return CameraPriority.pick(requests)
end

-- 1등을 다시 고르고, 바뀌었거나 force면 카메라에 반영해요.
local function update(force: boolean)
	local picked = pickOwner()
	if picked == currentOwner and not force then
		return
	end
	currentOwner = picked
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local index = if picked then indexOf(picked) else nil
	if index then
		runApply(entries[index], camera)
	else
		applyDefault(camera)
	end
end

function CameraDirector.request(owner: string, priority: number, apply: (camera: Camera) -> ())
	local index = indexOf(owner)
	if index then
		local entry = entries[index]
		entry.priority = priority
		entry.apply = apply
	else
		table.insert(entries, { owner = owner, priority = priority, apply = apply })
	end
	-- 요청한 owner가 1등이면 apply를 다시 불러요 (1등이 아니면 지금 카메라를 건드리지 않아요)
	update(pickOwner() == owner)
end

function CameraDirector.release(owner: string)
	local index = indexOf(owner)
	if index == nil then
		return
	end
	table.remove(entries, index)
	update(false)
end

function CameraDirector.current(): string?
	return currentOwner
end

function CameraDirector.isActive(owner: string): boolean
	return currentOwner == owner
end

return CameraDirector
