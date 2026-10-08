--!strict
-- 매치 흐름 훅 (m4-01). 다른 서비스(보상 m4-08, 로비 단상 m4-06, 플레이스 분리 m4-11 등)가
-- MatchService·EliminationService를 고치지 않고 매치 흐름을 들을 수 있는 곳이에요.
-- 서비스가 아니라 init/start가 없어요. 핸들러는 task.spawn + pcall로 따로 돌아서 하나가 에러 나거나
-- 기다려도(yield) 매치는 멈추지 않아요.
--
--   onMatchStart(fn(roomId, userIds))                          Starting 방송 직후 (매치를 시작한 전원)
--   onRoundStart(fn(roomId, roundIndex, roundCount, userIds))  출발(RoundActive) 순간, 그 라운드 레이서
--   onResult(fn(roomId, result: PlayerResult))                 PlayerResult를 방송할 때마다
--   onMatchEnd(fn(roomId, info))                               승부가 정해진 순간, 매치당 한 번
--        우승자가 있으면 Victory 방송 직후, 없으면 로비로 보내기 직전.
--        info = { winnerUserId: number?, standings: { Standing }, participants: { number } }
--        우승은 standings의 place 1이 아니라 winnerUserId로 판단해요 (결승 전원 리셋이면 winnerUserId = nil인데
--        place 1 칸이 있어요, m4-01 QA B3).
--   onWinnerShowcase(fn(info))                                 로비 단상에 세울 우승자
--        info = { userId, name, appearanceId }. 한 플레이스 모드는 Victory가 끝난 뒤 로비로 보내기 직전.
--        로비 플레이스는 매치에서 돌아온 첫 사람을 받을 때 PlaceService가 MatchResult를 읽어 보내요 (m4-11).
-- 각 onXxx는 해제 함수를 돌려줘요. fireXxx는 MatchService·EliminationService(·m4-11 PlaceService)만 불러요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

export type MatchEndInfo = {
	winnerUserId: number?,
	standings: { Types.Standing },
	participants: { number },
}

export type WinnerShowcaseInfo = {
	userId: number,
	name: string,
	appearanceId: string,
}

export type RoundStartHandler = (roomId: string, roundIndex: number, roundCount: number, userIds: { number }) -> ()

type Listeners = { (...any) -> () }

local MatchEvents = {}

local function newHook(name: string)
	local listeners: Listeners = {}
	local function subscribe(fn: (...any) -> ()): () -> ()
		table.insert(listeners, fn)
		return function()
			local index = table.find(listeners, fn)
			if index then
				table.remove(listeners, index)
			end
		end
	end
	local function fire(...: any)
		for _, fn in table.clone(listeners) do
			task.spawn(function(...: any)
				local ok, err = pcall(fn, ...)
				if not ok then
					warn(`[MatchEvents] {name} handler failed: {err}`)
				end
			end, ...)
		end
	end
	return subscribe, fire
end

local onMatchStart, fireMatchStart = newHook("MatchStart")
local onRoundStart, fireRoundStart = newHook("RoundStart")
local onResult, fireResult = newHook("Result")
local onMatchEnd, fireMatchEnd = newHook("MatchEnd")
local onWinnerShowcase, fireWinnerShowcase = newHook("WinnerShowcase")

function MatchEvents.onMatchStart(fn: (roomId: string, userIds: { number }) -> ()): () -> ()
	return onMatchStart(fn :: any)
end
function MatchEvents.fireMatchStart(roomId: string, userIds: { number })
	fireMatchStart(roomId, table.clone(userIds))
end

function MatchEvents.onRoundStart(fn: RoundStartHandler): () -> ()
	return onRoundStart(fn :: any)
end
function MatchEvents.fireRoundStart(roomId: string, roundIndex: number, roundCount: number, userIds: { number })
	fireRoundStart(roomId, roundIndex, roundCount, table.clone(userIds))
end

function MatchEvents.onResult(fn: (roomId: string, result: Types.PlayerResult) -> ()): () -> ()
	return onResult(fn :: any)
end
function MatchEvents.fireResult(roomId: string, result: Types.PlayerResult)
	fireResult(roomId, table.clone(result))
end

function MatchEvents.onMatchEnd(fn: (roomId: string, info: MatchEndInfo) -> ()): () -> ()
	return onMatchEnd(fn :: any)
end
function MatchEvents.fireMatchEnd(roomId: string, info: MatchEndInfo)
	fireMatchEnd(roomId, info)
end

function MatchEvents.onWinnerShowcase(fn: (info: WinnerShowcaseInfo) -> ()): () -> ()
	return onWinnerShowcase(fn :: any)
end
function MatchEvents.fireWinnerShowcase(info: WinnerShowcaseInfo)
	fireWinnerShowcase(info)
end

return MatchEvents
