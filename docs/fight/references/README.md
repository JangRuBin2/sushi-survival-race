# 스시 파이트 레퍼런스 모음

스시런에서 살릴 수 있는 조사 문서 13개와 콘셉트 이미지 5장을 2026-11-11에 이 폴더로 복사했어요(원본 `docs/` @ `a85fd669`, 원본은 스시런 문서로 그대로 둠). 각 문서 맨 위에 복사본 표시를 달고, 상대 링크는 원본 위치를 가리키게 고쳤어요.

## 조사 문서 → 파이트에서 쓰는 곳

| 문서 | 내용 | 파이트에서 쓰는 곳 |
|---|---|---|
| [REFERENCE-party-royale.md](REFERENCE-party-royale.md) | Fall Guys·Bro Falls 라운드·연출·다이브/잡기 조작감 | 박치기·잡고 던지기 손맛, 장외 연출 톤 (F1-03, F1-05) |
| [REFERENCE-final-overtime.md](REFERENCE-final-overtime.md) | 결승 시간 초과·연장전·관리자 기능 | 서든데스 규칙(GDD 7.2), 관리자 `fight` 명령 |
| [REFERENCE-m5-maps.md](REFERENCE-m5-maps.md) | 연어알 폭탄 접시·튀김 냄비·디저트 냉장고 사례 | 연어알 아레나·아이템, 튀김 냄비 위험 구간 |
| [REFERENCE-map-batch-3.md](REFERENCE-map-batch-3.md) | 찻잎 정원·온천탕 등 3차 맵 사례 | 찻잎 정원 아레나, 2차 아레나 후보 |
| [REFERENCE-large-maps.md](REFERENCE-large-maps.md) | 25~40명 맵 크기·인원 사례 | 대인원 난투(회전 원판, 3차) |
| [REFERENCE-map-art-direction.md](REFERENCE-map-art-direction.md) | "작은 초밥, 거대한 주방" 아트 기준(필수) | 아레나 아트 패스 전부 |
| [REFERENCE-map-production.md](REFERENCE-map-production.md) | 맵 제작 방식 비교 | 아레나 제작 방식 |
| [REFERENCE-touch-button-layout.md](REFERENCE-touch-button-layout.md) | 모바일 버튼 위치 편집 | 버튼 4개 배치(F1-03) |
| [REFERENCE-console-ui.md](REFERENCE-console-ui.md) | 게임패드 UI | 때리기 = B 버튼 충돌 정리(F1-03) |
| [REFERENCE-emotes.md](REFERENCE-emotes.md) | 이모트·춤 저작권, 세레모니 선례 | KO 도발·우승 세레모니 |
| [REFERENCE-roblox-monetization.md](REFERENCE-roblox-monetization.md) | 로블록스 코스메틱 시세 | 파이트 전용 상품(연출 팩 등) 가격 |
| [REFERENCE-winner-ticket-draw.md](REFERENCE-winner-ticket-draw.md) | 무료 뽑기권 | 파이트 우승 🎫 보상(GDD 8) |
| [REFERENCE-fresh-mackerel.md](REFERENCE-fresh-mackerel.md) | 고등어 전설 스킨·팔딱 움직임 | 맞았을 때 반응 연출 참고 |

## 콘셉트 이미지 (`images/`)

| 파일 | 쓰는 곳 |
|---|---|
| [maps-all.jpg](images/maps-all.jpg) | 스시런 맵 26개 시트 — 아레나 고르기 |
| [고등어 초밥 캐릭터 시트.png](images/고등어%20초밥%20캐릭터%20시트.png) | 캐릭터 표정·자세 (맞음·경직 자세) |
| [귀여운 우니와 장어 초밥 캐릭터 시트.png](images/귀여운%20우니와%20장어%20초밥%20캐릭터%20시트.png) | 캐릭터 표정·자세 |
| [귀여운 초밥 스킨 뽑기 UI.png](images/귀여운%20초밥%20스킨%20뽑기%20UI.png) | 결과 화면·보상 UI 톤 |
| [스시 서바이벌 레이스 신규 맵 6종.png](images/스시%20서바이벌%20레이스%20신규%20맵%206종.png) | 아레나 콘셉트 |

## 복사하지 않고 링크만 두는 것
- 제안서: [`../../proposals/`](../../proposals/) — `robux-gameplay.md`(능력치 판매 금지 근거), `emotes-and-pass-ceremony.md`, `skin-quality-and-variety.md`, `map-expansion-and-quality.md`, `large-maps.md`
- 렌더 캡처 `docs/renders/` (약 109MB) — 아레나 렌더는 `tools/render-map.luau`로 새로 뽑아요.
- 스펙 `docs/specs/m*.md` — 맵·조작 구현 근거로 읽기만 해요.
