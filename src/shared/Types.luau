--!strict
-- 서버와 클라이언트가 리모트로 주고받는 데이터 모양 (Remotes.luau 참고)

local Rules = require(script.Parent.Rules)

export type MapKind = Rules.MapKind

export type RoomState = "Waiting" | "InMatch"

-- 화면에 보일 문구 (m5-26). 서버는 문장 대신 키를 보내고, 클라이언트가 그 사람 언어로 만들어요 (Loc.text).
-- key는 src/shared/Localization/Strings.csv의 키, args는 {이름} 자리표시자 값 (숫자는 클라이언트가 1,234처럼).
export type LocText = { key: string, args: { [string]: string | number | LocText }? }

-- Notice 색 (m5-26부터 항상 보내요)
export type NoticeKind = "success" | "info" | "error"

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
	name: string, -- nameIsDefault면 방장 DisplayName (클라이언트가 room.defaultName "{name}의 초밥집"으로 보여 줘요)
	nameIsDefault: boolean?, -- 이름 없이 만든 방 (m5-26)
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
	name: string, -- nameIsDefault면 방장 DisplayName (RoomSnapshot과 같아요)
	nameIsDefault: boolean?, -- m5-26
	maxPlayers: number,
	memberCount: number,
	state: RoomState,
	-- true면 다른 로비 서버의 방 (m4-11). id = "<JobId>:<roomId>", 누르면 그 서버로 텔레포트해서 들어가요.
	remote: boolean?,
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
	overtime: boolean?, -- 결승 연장전 중이면 true (m5-01)
	collapseAt: number?, -- 연장전에서 바닥이 다 사라지는 시각 (workspace:GetServerTimeNow() 기준)
}

-- 탈락 사유 (탈락 연출용). Fall = 맵 낙하 판정, Reset = 리셋·사망·캐릭터 없음, Left = 방/게임을 나감,
-- Timeout = 시간 종료·통과 인원이 다 차서 남은 사람이 탈락 (m3-09)
export type EliminationCause = "Fall" | "Reset" | "Left" | "Timeout"

export type PlayerResult = {
	userId: number,
	result: "Passed" | "Eliminated" | "Won",
	place: number, -- 통과 순서 또는 최종 등수
	-- Eliminated일 때만 (Passed·Won은 nil).
	cause: EliminationCause?,
	-- Eliminated일 때 탈락 위치 (없으면 nil). Fall은 마지막으로 땅을 밟고 있던 위치(m4-01, m3-03 B2),
	-- 그 밖은 탈락 순간 HumanoidRootPart 위치.
	position: Vector3?,
}

-- 터치 버튼 배치 (m5-41, Shared.TouchLayoutLogic). 버튼 하나 = 가운데 위치(안전 영역 폭·높이에 대한 비율 0~1)
-- + 크기(짧은 변에 대한 비율). 저장은 소수 셋째 자리까지
export type TouchButtonSpot = { x: number, y: number, s: number }
export type TouchLayoutPreset = "default" | "large" | "compact" | "custom"
export type TouchLayout = {
	v: number, -- 모양 버전 (지금 1)
	preset: TouchLayoutPreset,
	jump: TouchButtonSpot,
	dive: TouchButtonSpot,
	grab: TouchButtonSpot,
}
export type TouchLayoutBucket = "phone" | "tablet" -- 짧은 변 ≤ 500이면 phone
-- 기기 묶음별 배치. 없는 묶음은 기본 배치
export type TouchLayoutSettings = { phone: TouchLayout?, tablet: TouchLayout? }

-- 플레이어 설정 (m4-01). muteLevel: 1 소리 켬, 2 음악 끔, 3 모두 끔 (m3-08 음소거 단계와 같음)
-- touchLayout (m5-41): 편집한 터치 버튼 배치. 없으면 기본 배치 (프로필 버전 3 그대로, 선택 칸)
export type Settings = {
	muteLevel: number,
	touchLayout: TouchLayoutSettings?,
}

-- SaveSettings 요청 (m5-41부터 부분 저장): 있는 칸만 바꿔요. 하나라도 틀리면 요청 전체를 무시해요.
-- touchLayout = { bucket, layout } 이면 그 묶음 저장, { bucket, reset = true } 이면 그 묶음을 지워요 (기본으로)
export type TouchLayoutChange = { bucket: TouchLayoutBucket, layout: TouchLayout?, reset: boolean? }
export type SettingsPatch = {
	muteLevel: number?,
	touchLayout: TouchLayoutChange?,
}

-- 클라이언트에 보내는 내 프로필 (ProfileUpdated, ProfileSchema.toView)
export type ProfileView = {
	coins: number,
	wins: number,
	title: string?,
	equippedSkin: string,
	ownedSkins: { string }, -- 이름순
	settings: Settings,
	persistent: boolean, -- false면 저장되지 않는 프로필 (Studio 메모리 모드·로드 실패)
	eventTokens: { [string]: number }, -- 이벤트 id → 모은 이벤트 재화 (m5-03/m5-07)
	ownedFx: { string }, -- 가진 연출 id, 이름순 (m5-08)
	equippedFx: { Elimination: string?, Victory: string? }, -- 입은 연출 (m5-08)
	boughtOffers: { string }, -- 한 번만 사는 상품 중 산 것 id, 이름순 (m5-08)
	vip: boolean, -- VIP 게임 패스 확인 결과 (저장 안 함, DataService.setViewExtra로 m5-08이 채움)
	drawTickets: number, -- 🎫 우승자 뽑기 티켓 (m5-31, 0~Config.Draw.MaxTickets)
	-- Studio 전부 입기가 켜졌는가 (m5-31, Config.DEBUG.unlockAllSkinsInStudio — 저장 안 함). true면 탈의실 카드가 "입기 (Studio)"
	studioUnlockAll: boolean,
}

-- 밥알 코인 지급 이유 (GDD 9.4, m4-08). Code = 코드 보상(m5-10), MatchPlayed = 판 참가(이벤트 재화, m5-07)
export type RewardReason = "RoundPass" | "FinalQualify" | "Win" | "DailyFirstMatch" | "Code" | "MatchPlayed"

export type RewardGrant = {
	reason: RewardReason,
	amount: number, -- 이번에 받은 코인 (이벤트 재화만 받으면 0)
	total: number, -- 지급 뒤 코인 합계
	tokens: number?, -- 이번에 받은 이벤트 재화 (m5-07/m5-10)
	tokenTotal: number?, -- 지급 뒤 그 이벤트 재화 합계
	eventId: string?, -- 재화의 이벤트 id (Shared.Seasons)
	tickets: number?, -- 이번에 받은 🎫 뽑기 티켓 (m5-31, Win일 때만. 가득이면 0)
	ticketsFull: boolean?, -- 티켓이 가득 차서(Config.Draw.MaxTickets) 이번 우승 티켓을 못 받았으면 true
}

-- 🎫 뽑기 등급 (m5-31, Shared.Skins.DrawGrade와 같아요). 상점 등급(tier)과 별개
export type DrawGrade = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

-- 🎫 뽑기 결과 (m5-31, DrawTicket이 돌려줘요). 꽝은 없어요: Skin = 새 스킨을 얻음,
-- Duplicate = 이미 가진 스킨이 나와서 그 뽑기 등급만큼 밥알 코인으로 바뀜 (Config.Draw.DuplicateCoins)
export type DrawResult = {
	kind: "Skin" | "Duplicate",
	skinId: string, -- 나온 스킨 id (Duplicate여도 무엇이 나왔는지 보여 줘요)
	grade: DrawGrade, -- 뽑기 등급
	coins: number, -- 이번에 받은 밥알 코인 (Skin이면 0)
	ticketsLeft: number, -- 뽑은 뒤 남은 뽑기권
}

return {}
