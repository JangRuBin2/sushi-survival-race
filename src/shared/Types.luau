--!strict
-- 서버와 클라이언트가 리모트로 주고받는 데이터 모양 (Remotes.luau 참고)

local Rules = require(script.Parent.Rules)

export type MapKind = Rules.MapKind

export type RoomState = "Waiting" | "InMatch"

-- 방 만들기 요청 (GDD 3.2). 서버에서 Config.Room 기준으로 검증해요.
export type RoomSettings = {
	maxPlayers: number,
	isPrivate: boolean,
	name: string?,
}

export type MemberInfo = {
	userId: number,
	name: string,
}

-- 방 멤버에게만 보내는 상세 정보 (비공개 방 코드 포함)
export type RoomSnapshot = {
	id: string,
	name: string,
	maxPlayers: number,
	isPrivate: boolean,
	code: string?,
	hostUserId: number,
	members: { MemberInfo },
	state: RoomState,
	autoStartAt: number?, -- workspace:GetServerTimeNow() 기준
}

-- 로비 방 목록에 보이는 공개 방 요약
export type RoomListing = {
	id: string,
	name: string,
	maxPlayers: number,
	memberCount: number,
	state: RoomState,
}

-- 매치 상태 머신 단계 (GDD 11.4)
export type MatchPhase = "Starting" | "RoundIntro" | "RoundActive" | "RoundResults" | "Victory"

export type MatchPhaseInfo = {
	phase: MatchPhase,
	endsAt: number?, -- 이 단계가 끝나는 시각 (workspace:GetServerTimeNow() 기준)
	roundIndex: number?,
	roundCount: number?,
	mapId: string?,
	mapName: string?,
	mapKind: MapKind?,
	rule: string?, -- 라운드 소개 한 줄 규칙
	winnerUserId: number?, -- Victory
	aliveUserIds: { number }?, -- 이 매치에서 아직 탈락하지 않은 플레이어 (모든 단계, 값은 m2-05가 채움)
	standings: { Standing }?, -- Victory: 최종 순위 (1등부터, 값은 m2-05가 채움)
}

-- 매치 최종 순위 한 줄
export type Standing = {
	userId: number,
	name: string,
	place: number,
}

export type RoundProgress = {
	passed: number,
	target: number,
	remaining: number, -- 아직 통과/탈락하지 않은 인원
	racerUserIds: { number }, -- 이번 라운드에서 아직 통과/탈락하지 않은 플레이어
}

export type PlayerResult = {
	userId: number,
	result: "Passed" | "Eliminated" | "Won",
	place: number, -- 통과 순서 또는 최종 등수
}

return {}
