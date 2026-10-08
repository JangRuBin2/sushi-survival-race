--!strict
-- 효과음·배경음 (껍데기 — 채우는 스펙: m3-08). 지금은 아무 소리도 내지 않아요.
--   Sfx.play(cue, at?)    효과음. at이 있으면 그 파트/위치에서 3D로. cue는 Shared.SfxCues의 이름만.
--   Sfx.setMusic(name?)   배경음 바꾸기 (nil이면 끄기). name은 SfxCues.Music의 이름만.
--   Sfx.start(gui)        init.client.luau가 다른 컨트롤러와 함께 불러요.
-- start 전에 불려도 에러 없이 무시해요. 모르는 이름은 이름당 한 번만 경고해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SfxCues = require(ReplicatedStorage.Shared.SfxCues)

local Sfx = {}

local warned: { [string]: boolean } = {}

local function warnOnce(kind: string, name: string)
	local key = `{kind}:{name}`
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[Sfx] unknown {kind} "{name}" (see Shared.SfxCues)`)
end

function Sfx.play(cue: string, _at: (BasePart | Vector3)?)
	if not SfxCues.isEffect(cue) then
		warnOnce("cue", cue)
		return
	end
end

function Sfx.setMusic(name: string?)
	if name ~= nil and not SfxCues.isMusic(name) then
		warnOnce("music", name)
		return
	end
end

function Sfx.start(_gui: Instance) end

return Sfx
