--!strict
-- 리모트 목록. 이름은 여기서만 정의해요 (병렬 작업 중에는 한 에이전트만 수정).
-- 서버가 처음 require할 때 만들고, 클라이언트는 만들어질 때까지 기다려요.
-- 데이터 모양은 Types.luau 참고. 클라이언트가 보낸 인자는 서버에서 항상 검증해요.
--
-- 클라이언트 → 서버 요청 (RemoteFunction, 반환: ok: boolean, err: string?)
--   CreateRoom(settings: RoomSettings)
--   JoinRoom(roomId: string)
--   JoinByCode(code: string)
--   QuickJoin()
--   LeaveRoom()            방 대기실에서 나가기, 탈락 후 "로비로"
--   StartRoom()            방장만
--   EquipSkin(skinId: string)     보유한 스킨 입기 (m4-13, ShopService: 라운드·연출 중 거절, Config.Shop.RequestCooldown)
--   BuyWithCoins(skinId: string)  일반 스킨 코인 해금 + 자동 장착 (m4-13, ShopService)
--   RequestRobuxPurchase(skinId: string)  로벅스 결제 창 열기 (m4-14, RobuxShopService: 상품·미보유·저장 가능 검증,
--                                 Config.Shop.PurchaseRequestCooldown). 지급은 ProcessReceipt가 해요
--
-- 서버 → 클라이언트 알림 (RemoteEvent)
--   RoomList(rooms: { RoomListing })         로비에 있는 플레이어에게 공개 방 목록
--   RoomUpdated(room: RoomSnapshot?)         내 방 상태 (nil이면 방에서 나감)
--   MatchPhase(phase: MatchPhaseInfo)        매치 상태 머신 단계가 바뀔 때
--   RoundProgress(progress: RoundProgress)   통과 인원 / 목표 인원 바
--   PlayerResult(result: PlayerResult)       누군가 통과/탈락/우승했을 때
--   MapSfx(cue: string, part: BasePart?, position: Vector3)  장애물 소리 (m3-09, 그 방 사람에게만 — 방을 모르면 모든 클라이언트. 소리는 클라이언트 Sfx가 내요)
--   ProfileUpdated(view: ProfileView)        내 프로필이 로드되거나 바뀔 때, 본인에게만 (m4-01, DataService)
--   RewardGranted(grant: RewardGrant)        코인을 받을 때, 본인에게만 (m4-08, RewardService)
--   Notice(message: string)                  짧은 안내 한 줄, 본인에게만 (m4-11: 텔레포트 실패·서버 이동 중 등)
--
-- 클라이언트 → 서버 알림 (RemoteEvent, 반환 없음. 서버가 타입·요청 간격을 검증해요)
--   GrabInput(holding: boolean)              잡기 버튼 누름(true)/뗌(false) (m3-07, Config.Grab.InputMinInterval)
--   SaveSettings(settings: Settings)         설정 저장 { muteLevel = 1~3 정수 } (m4-01, Config.Data.SettingsMinInterval)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FUNCTIONS = {
	"CreateRoom",
	"JoinRoom",
	"JoinByCode",
	"QuickJoin",
	"LeaveRoom",
	"StartRoom",
	"EquipSkin",
	"BuyWithCoins",
	"RequestRobuxPurchase",
}
local EVENTS = {
	"RoomList",
	"RoomUpdated",
	"MatchPhase",
	"RoundProgress",
	"PlayerResult",
	"GrabInput",
	"MapSfx",
	"ProfileUpdated",
	"RewardGranted",
	"SaveSettings",
	"Notice",
}

local FOLDER_NAME = "Remotes"

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Remotes = {}

function Remotes.fn(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), `unknown remote function {name}`)
	return folder:WaitForChild(name) :: RemoteFunction
end

function Remotes.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), `unknown remote event {name}`)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
