--!strict
-- 테스트용 관리자 (m5-02). 비밀번호·키는 절대 넣지 않아요. UserId는 프로필 주소 숫자(roblox.com/users/<숫자>/profile).
-- ServerScriptService 아래라 클라이언트에 복제되지 않아요 (누가 관리자인지는 서버만 알아요).
-- 판단은 Shared.AdminLogic.isAdmin, 적용은 AdminService.
return {
	UserIds = { 11402290839 } :: { number }, -- 사용자 본인 (2026-10-08 알려 줌)
	IncludeOwner = true, -- 게임을 개인 계정으로 퍼블리시했으면 소유자도 관리자
	StudioAllAdmins = true, -- Studio에서는 모두 관리자. false면 Studio에서도 위 목록만 (비관리자 화면 확인용)
	LiveEnabled = true, -- false면 실서버에서는 아무도 관리자가 아님 (공개 출시 때 끄고 싶으면)
}
