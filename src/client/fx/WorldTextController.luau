--!strict
-- 서버가 키만 달아 둔 월드 글씨(WorldText.mark)를 이 플레이어 언어로 채워요 (m5-26 2단계).
-- 예: 간장 늪 와사비 "매워!!" (map.soy-swamp.spicy). 글씨가 생길 때 한 번 채우고, 키가 바뀌면 다시 채워요.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loc = require(script.Parent.Parent.Loc)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local WorldText = require(ReplicatedStorage.Shared.WorldText)

local WorldTextController = {}

local function render(instance: Instance)
	if not instance:IsA("TextLabel") then
		return
	end
	local key = WorldText.keyOf(instance:GetAttribute(Attributes.LocKey))
	if key == nil then
		return
	end
	instance.AutoLocalize = false
	instance.Text = Loc.t(key)
end

local function watch(instance: Instance)
	render(instance)
	instance:GetAttributeChangedSignal(Attributes.LocKey):Connect(function()
		render(instance)
	end)
end

function WorldTextController.start(_gui: Instance)
	CollectionService:GetInstanceAddedSignal(WorldText.TAG):Connect(watch)
	for _, instance in CollectionService:GetTagged(WorldText.TAG) do
		watch(instance)
	end
end

return WorldTextController
