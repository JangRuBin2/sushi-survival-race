--!strict
-- 장애물 소리 (m3-09). 서버 맵 모듈이 장애물이 경고하거나 움직이는 순간 부르면 근처 플레이어에게 3D로 들려요.
--   MapSfx.play(part, cue)   cue는 Shared.SfxCues의 장애물 이름. SfxLibrary에 id가 없으면 아무것도 안 해요.
--   MapSfx.setAudience(fn)   서버가 "이 파트 소리를 받을 사람" 함수를 넣어요 (그 방 사람만, 모르면 전부).
-- 같은 파트·같은 cue는 MapSfxLogic.MIN_INTERVAL(Config.Fx.MapSfxMinInterval) 안에 다시 울리지 않아요.
--
-- 소리는 서버가 Sound를 만들지 않고 RemoteEvent "MapSfx"(cue, part, position)로 알리면 클라이언트 Sfx가 내요.
-- 그래야 pitch·흔들림, 음소거 "모두 끔", 동시 재생 한도가 다른 효과음과 같아요 (m3-08 QA B4, 스펙 결정 기록).
-- 맵 파일은 이 호출만 넣어요 — 판정·타이밍·태그 규칙은 바꾸지 않아요.
-- Roblox API(Remotes 포함)는 play 안에서만 써서 Lune에서 맵 모듈을 require해도 안전해요.

local MapSfxLogic = require(script.Parent.MapSfxLogic)
local SfxLibrary = require(script.Parent.Parent.SfxLibrary)

local MapSfx = {}

local limiter = MapSfxLogic.newLimiter()
local event: RemoteEvent? = nil

local function remote(): RemoteEvent?
	if event == nil then
		local RunService = game:GetService("RunService")
		if not RunService:IsServer() then
			return nil
		end
		local Remotes = require(script.Parent.Parent.Remotes) :: any
		event = Remotes.event("MapSfx")
	end
	return event
end

-- 소리를 받을 사람을 고르는 함수 (서버 RoundService가 init에서 넣어요: 그 방 사람들).
-- 없거나 nil을 돌려주면(방을 모름) 모든 클라이언트에 보내요. 클라이언트는 120 studs 밖 소리를 버려요.
-- shared 모듈이 서버 RoomService를 require하지 않게(순환 방지) 함수를 받아요 (m3-09 QA B2).
local audienceOf: ((part: BasePart) -> { Player }?)? = nil

function MapSfx.setAudience(resolver: ((part: BasePart) -> { Player }?)?)
	audienceOf = resolver
end

function MapSfx.play(part: BasePart?, cue: string)
	local entry = SfxLibrary.get(cue)
	if entry == nil or entry.id == nil then
		return
	end
	if part == nil or part.Parent == nil then
		return
	end
	if not MapSfxLogic.allow(limiter, part, cue, os.clock()) then
		return
	end
	local target = remote()
	if target == nil then
		return
	end
	local audience = if audienceOf then audienceOf(part) else nil
	if audience == nil then
		target:FireAllClients(cue, part, part.Position)
		return
	end
	for _, player in audience do
		target:FireClient(player, cue, part, part.Position)
	end
end

return MapSfx
