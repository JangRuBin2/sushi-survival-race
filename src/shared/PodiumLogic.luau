--!strict
-- 로비 우승자 단상 이름표 (m4-06, m5-26 2단계). 순수 로직 — Roblox API 없음.
-- 서버(LobbyService)는 문장을 만들지 않고 Lobby.Podium 폴더에 이름·숫자만 달아요
-- (Attributes.WinnerName, Attributes.WinnerWins). 클라이언트(LobbyFxController)가 여기 view로 LocText를 만들고
-- Loc.text로 그 사람 언어로 풀어요. 이름표 TextLabel은 AutoLocalize = false (플레이어 이름을 번역하지 않게).
--   PodiumLogic.titleWins(wins)   wins 이하인 칭호 중 가장 높은 칭호의 기준 승수 (Config.Titles), 없으면 nil
--   PodiumLogic.view(name, wins)  { name, title?, wins? } — 속성 값을 그대로 넣어도 돼요 (모양이 틀리면 빈 상태·이름만)

local Config = require(script.Parent.Config)
local LocalizeLogic = require(script.Parent.LocalizeLogic)
local Types = require(script.Parent.Types)

local PodiumLogic = {}

export type View = {
	name: Types.LocText,
	title: Types.LocText?,
	wins: Types.LocText?,
}

PodiumLogic.MAX_NAME_LENGTH = 60 -- DisplayName은 20자 이하. 이보다 길면 이상한 값이라 빈 상태로 봐요

function PodiumLogic.titleWins(wins: number): number?
	local found: number? = nil
	for _, entry in Config.Titles do
		if wins >= entry.wins then
			found = entry.wins
		end
	end
	return found
end

local function isWins(value: any): boolean
	return type(value) == "number" and value >= 1 and value == math.floor(value) and value < math.huge
end

function PodiumLogic.view(name: any, wins: any): View
	if type(name) ~= "string" or name == "" or #name > PodiumLogic.MAX_NAME_LENGTH then
		return { name = LocalizeLogic.text("lobby.podium.empty") }
	end
	local view: View = { name = LocalizeLogic.text("lobby.podium.winner", { name = name }) }
	if isWins(wins) then
		local threshold = PodiumLogic.titleWins(wins)
		if threshold then
			view.title = LocalizeLogic.text(LocalizeLogic.titleKey(threshold))
		end
		view.wins = LocalizeLogic.text("lobby.podium.wins", { wins = wins })
	end
	return view
end

return PodiumLogic
