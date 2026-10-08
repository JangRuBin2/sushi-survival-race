# m5-02 admin skin preview — 개발 작업 기록

## 2026-10-08 — 구현 완료, in-qa (최신)
- **브랜치**: `m5-02-admin` (origin/main b1ef1d2에서 분기), push 완료.
- **끝난 것**: 스펙 범위 1~7, AC1~AC5. 관리자 판단은 서버 UserId·Studio·개인 소유자만(비밀번호·키 없음). 목록은 서버 전용 `src/server/AdminConfig.luau`.
  - 순수: `src/shared/AdminLogic.luau` (isAdmin·checkPreview·pickAppearance·MemoryStore 키/값).
  - 서버: `src/server/AdminService.luau` (관리자 표, IsAdmin 속성, AdminPreviewSkin 리모트, MemoryStore `AdminPreview_v1` 1시간), `ShopService` 미리보기 슬롯.
  - 클라이언트: `AdminController`(IsAdmin일 때만 생성) + `AdminPanel`(왼쪽 가운데 "🛠").
  - 테스트: `tests/admin-logic.spec.luau` 24개 — 순수 AC1~AC4 + 가짜 Roblox로 AdminService·ShopService를 돌려 클라이언트가 단 IsAdmin 무시, 프로필 update/saveNow 0회, 장착 시 미리보기 꺼짐, MemoryStore 쓰기·다른 서버 복원·비관리자 미복원, 소스 검사(DataService·Reward·Purchase 미참조).
- **검증**: rojo build OK, stylua --check OK, selene 0/0/0, lune 1045 passed / 0 failed, luau-lsp analyze 에러 0.
- **남은 것**: QA, Studio AC6~AC11(스펙 개발 메모 "Studio 확인 방법"), 실서버 AC12·AC13.
- **다음에 할 첫 단계**: QA가 `AdminService.onPreview` 검사 순서와 `ShopService.assignPreview`/`clearPreview` 호출 지점을 검토.
- **막힌 점**: 없음. Studio가 없어 화면·외형은 확인 못 함.
- **메모**
  - m5-01과 병합 때 숫자 테스트 충돌 가능: `m4-foundation`(리모트 21), `camera-priority`(속성 13).
  - 기존 `m4-14-qa` 가짜 환경에 Shared `AdminLogic`·`Attributes`를 더했어요(ShopService가 require).
