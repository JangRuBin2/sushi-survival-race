--!strict
-- 서버가 직접 글씨를 만들어야 하는 드문 곳 (m5-26): player:Kick 메시지처럼 클라이언트가 풀 수 없는 문구.
-- 번역기를 기다리지 않고 같은 카탈로그(Shared.Localization.Strings)와 player.LocaleId로 한국어·영어 중 하나를 골라요.
-- 그 밖의 서버 메시지는 LocText를 보내고 클라이언트(Loc)가 풀어요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalizeLogic = require(ReplicatedStorage.Shared.LocalizeLogic)
local Types = require(ReplicatedStorage.Shared.Types)

local ServerLoc = {}

local catalog: LocalizeLogic.Catalog? = nil

local function getCatalog(): LocalizeLogic.Catalog
	local current = catalog
	if current then
		return current
	end
	local built: LocalizeLogic.Catalog = {}
	local ok, err = pcall(function()
		local folder = ReplicatedStorage:FindFirstChild("Shared")
		local localization = folder and folder:FindFirstChild("Localization")
		local tableInstance = localization and localization:FindFirstChild("Strings")
		if tableInstance and tableInstance:IsA("LocalizationTable") then
			built = LocalizeLogic.buildCatalog(tableInstance:GetEntries() :: any)
		end
	end)
	if not ok then
		warn(`[ServerLoc] could not read the string catalog: {err}`)
	end
	catalog = built
	return built
end

-- 그 플레이어 언어의 글씨 (한국어면 원문, 그 밖은 영어)
function ServerLoc.render(player: Player, loc: Types.LocText): string
	local language = LocalizeLogic.languageOf(player.LocaleId)
	return LocalizeLogic.render(getCatalog(), language, loc)
end

return ServerLoc
