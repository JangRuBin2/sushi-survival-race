--!strict
-- 서버가 만드는 월드 글씨(BillboardGui·SurfaceGui의 TextLabel)를 그 플레이어 언어로 보여 주는 표시 (m5-26 2단계).
-- 서버는 한국어 문장을 넣지 않고 카탈로그 키만 달아요: WorldText.mark(label, "map.soy-swamp.spicy").
--   → label.Text = "", AutoLocalize = false, 속성 Attributes.LocKey = 키, 태그 WorldText.TAG.
-- 클라이언트 WorldTextController가 이 태그가 붙은 글씨를 찾아 Loc.t(키)로 채워요.
-- 인자가 있는 문구는 이걸로 하지 않아요 (속성은 표를 못 담아요) — 단상처럼 숫자를 속성에 따로 두고 클라이언트가 풀어요.
--   WorldText.keyOf(value)      속성 값 → 올바른 키면 그대로, 아니면 nil (순수)
--   WorldText.mark(label, key)  서버에서, 부모에 넣기 전에 (Roblox API는 함수 안에서만 불러요)

local Attributes = require(script.Parent.Attributes)
local LocalizeLogic = require(script.Parent.LocalizeLogic)

local WorldText = {}

WorldText.TAG = "LocalizedWorldText"

function WorldText.keyOf(value: any): string?
	if type(value) == "string" and LocalizeLogic.isValidKey(value) then
		return value
	end
	return nil
end

function WorldText.mark(label: TextLabel, key: string)
	assert(WorldText.keyOf(key) ~= nil, `WorldText.mark: bad key {key}`)
	label.Text = ""
	label.AutoLocalize = false
	label:SetAttribute(Attributes.LocKey, key)
	game:GetService("CollectionService"):AddTag(label, WorldText.TAG)
end

return WorldText
