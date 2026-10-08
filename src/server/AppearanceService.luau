--!strict
-- 캐릭터 외형을 입히는 유일한 곳 (CLAUDE.md "applyAppearance"). 껍데기 — 채우는 스펙: m3-02.
-- 지금은 캐릭터에 AppearanceId 속성만 달아요. 스킨·상점이 붙으면 여기서 플레이어의 스킨 id를 골라요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)

local AppearanceService = {}

function AppearanceService.applyAppearance(character: Model, appearanceId: string?)
	character:SetAttribute(Attributes.AppearanceId, appearanceId or Config.Appearance.Default)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		AppearanceService.applyAppearance(character, nil)
	end)
	if player.Character then
		AppearanceService.applyAppearance(player.Character, nil)
	end
end

function AppearanceService.init() end

function AppearanceService.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return AppearanceService
