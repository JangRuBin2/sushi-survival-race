# REFERENCE — 이모트(감정표현)·춤 밈 저작권, 가격 시세, 통과 세레모니 선례

조사일: **2026-10-09** (planner). `docs/proposals/emotes-and-pass-ceremony.md`의 근거.
표기: **[원문]** = WebFetch 또는 검색 결과에 인용된 1차 자료를 직접 확인 / **[검색]** = 검색 결과 요약만 확인(원문 미확인, 페이월·403·402 등으로 못 엶) / **확인 못 함** = 찾지 못함. 추정은 "추정"이라고 따로 적는다.

---

## 1. 로블록스 공식 이모트(Emotes) 시스템

| 항목 | 내용 | 근거 |
|---|---|---|
| 공식 문서 | `create.roblox.com/docs/characters/emotes` | [원문] |
| 트리거 3가지 | ① 화면 우측 상단 이모트 메뉴 ② 채팅 명령 `/e <이름>`(예 `/e cheer`) ③ 스크립트 API `Humanoid:PlayEmote()` | [원문] |
| 기본 무료 이모트 | 전원이 처음부터 가지고 있는 기본값(춤·손 흔들기·가리키기 등) | [검색] |
| 메뉴를 꺼도 | 채팅 명령 `/e`는 여전히 동작 — 완전히 막으려면 서버가 양쪽 다 통제해야 함 | [원문] |
| 커스터마이즈 API | `HumanoidDescription:SetEmotes()`(보유 목록), `SetEquippedEmotes()`(메뉴에 올릴 최대 8개) | [원문] |
| 이동과의 상호작용 | 애니메이션 우선순위는 `Core < Idle < Movement < Action` 순. 이동을 시작하면(`Humanoid.Running`/`GetState()`) 이모트가 대부분 자동으로 끊긴다 — DevForum에 "움직이면 이모트가 멈춘다", "멈추게 하려면 직접 끊어야 한다"는 질문·답변이 다수 | [검색, DevForum 다수 스레드] |
| UGC 판매 개방 | 2025-08-07부터 크리에이터가 마켓플레이스에 커스텀 이모트를 올려 팔 수 있게 됨. 업로드 수수료 80 R$(이미시브 마스크 포함이면 500 R$), 퍼블리싱 어드밴스(환불 가능한 선결제) 1,500 R$(비한정)·10,000 R$(한정판) | [원문, DevForum "Avatar Creators Can Publish and Sell Emotes on Marketplace"] |
| 마켓플레이스 개별 가격대 | 1 R$, 55 R$, 80 R$ 등 예시 확인 | [검색] |

**읽은 것**: 로블록스 엔진 자체가 "이동하면 이모트가 끊긴다"를 기본값으로 둔다는 사실은, 우리가 설계하려는 "달리는 라운드 중 이모트 금지" 규칙이 로블록스의 기본 공학 방향과도 맞는다는 근거가 된다(우리는 서버 판정으로 아예 입력을 막지만, 클라이언트 쪽 애니메이션 우선순위 관행도 같은 방향).

---

## 2. 인기 로블록스 파티 게임 3개 비교

| 게임 | 이모트 방식 | 근거 |
|---|---|---|
| **Brookhaven RP** | 105개 애니메이션(이모트·춤 포함), 메뉴 또는 `/e <이름>` 채팅 명령으로 트리거. 대부분 무료, **9개는 VIP 게임패스 전용**, 일부는 콜라보 기간한정 | [검색, gfinityesports·robloxden] |
| **Royale High** | 춤·이모트가 **개별 카탈로그 아이템**(아바타 샵 UGC 상품)으로 팔림. 확인한 매물 대부분 **50~55 R$** | [검색, rolimons 매물가 다수] |
| **Adopt Me** | "이모트" 전용 개별 상품은 찾지 못함(**확인 못 함**) — 대신 **VIP 게임패스(640 R$, 1회 영구)**·**월 구독(Pets Plus 299 R$/월)** 같은 패스형으로 치장 콘텐츠를 묶어 판다는 패턴만 확인 | [검색] |
| Stumble Guys (참고, 비-로블록스지만 같은 레이스·엘리미네이션 장르) | "타운트(Taunt)" 이모트를 **"간발의 차로 추월했을 때나 결승선에서 기다릴 때" 쓰라**고 공식 안내 — 우리 게임의 "대기석에서 관전 중"과 정확히 같은 시점. 단 같은 메뉴에 **"능력"(블록 던지기, 번개로 기절시키기 같은 공격형)**도 섞여 있고, Steam 토론에 "Pay-to-Win?"이라는 스레드가 있을 만큼 판정에 영향을 주는 상품과 겉모습 상품이 뒤섞여 있다는 비판이 있음 | [검색, stumbleguys.com 공식 안내 + Steam 커뮤니티 토론] |

**읽은 것**: Stumble Guys 사례는 정확히 우리가 피해야 할 전례다. GDD 9.1 "능력치를 파는 상품은 없다"를 지키려면, 이모트(순수 겉모습)와 혹시 미래에 생길 수 있는 "능력형 상품"은 절대 같은 메뉴·같은 개념으로 묶지 않아야 한다. 반대로 "통과 후 대기 시간에 이모트를 쓴다"는 트리거 시점 설계는 그대로 가져올 만하다.

---

## 3. 밈 댄스의 저작권 리스크 — Fortnite 사례

| 항목 | 내용 | 근거 |
|---|---|---|
| 소송 당사자 | Alfonso Ribeiro("Carlton Dance"), 래퍼 **2 Milly**("Milly Rock" → 게임 내 "Swipe It"), **Backpack Kid**(Russell Horning, "플로스" 춤 → 게임 내 "Floss"), "Orange Shirt Kid"의 어머니("오렌지 저스티스") 등 다수가 Epic Games를 상대로 소송 | [원문, PC Gamer·Comicbook.com·Hollywood Reporter·PCGamesN] |
| Epic의 항변 | 소송이 "표현의 자유와 근본적으로 배치된다"("at odds with free speech principles"), "**누구도 춤 동작 자체를 소유할 수 없다**"("No one can own a dance step")고 주장 | [원문, PCGamesN] |
| 결말 | 2019년 미 연방대법원이 "저작권청의 등록 결정 전에는 저작권 침해 소송을 제기할 수 없다"는 별건 판례를 내놓자, 리베이로·2 Milly·Backpack Kid·Orange Shirt Kid 측이 소송을 **불이익 없이(without prejudice) 취하** — 법원이 "안무는 저작권 대상이 아니다"를 확정 판결한 게 아니라, 절차적 이유로 일단 멈췄을 뿐이고 **재청구가 가능한 상태로 남음** | [원문, Hollywood Reporter·win.gg] |
| 교훈 | "유명인의 특정 안무를 그대로 게임에 넣는 것"은 법적으로 완전히 안전하다고 확정된 적이 없다. Epic Games 같은 대형 스튜디오도 수년간 소송에 시달렸고, 다수의 유명 밈 댄스(플로스 등)는 결국 **정식 라이선스를 사서 쓰는 쪽으로 선회**했다(라이선스 비용을 감당할 수 있는 대기업이라 가능한 선택) | 추정(일반적으로 알려진 업계 흐름, 이 조사에서 라이선스 전환 시점의 1차 자료까지는 확인 못 함) |

**결론**: 이 프로젝트는 라이선스 비용을 지불할 수 없는 소규모 개발이므로, **원본 밈 안무(플로스, 밀리락, 칼튼 댄스, 오렌지 저스티스 등)를 그대로 베끼는 건 절대 하지 않는다.** "유행하는 춤에서 영감을 받되 안무 자체는 새로 만든, 알아볼 수는 있지만 똑같지는 않은 동작"으로 재해석하는 것을 기본 원칙으로 한다.

---

## 4. "통과 세레모니" 같은 짧은 축하 연출의 선례

| 게임 | 내용 | 근거 |
|---|---|---|
| **Fall Guys** | 라운드를 통과하면(레이스는 결승선 통과, 점수형은 목표 점수 달성) 화면에 초록색 **"QUALIFIED"** 텍스트가 뜬다. "Qualified Banner"라는 명칭의 **배지(아이템)** 도 따로 있다 | [검색, Fandom] |
| 〃 세레모니 애니메이션 유무 | 통과 순간 캐릭터(빈)가 춤을 추거나 전용 포즈를 취하는지까지는 원문을 확인하지 못함(출처 페이지가 402 결제 요구로 막힘) | **확인 못 함** |
| **Stumble Guys** | "통과 세레모니"를 게임이 자동으로 틀어주지 않는다 — 대신 플레이어가 결승선에서 기다리는 동안 **직접 타운트 이모트를 트리거**하는 문화를 공식 가이드가 권장 | [검색] |

**정리**: 업계에 "통과 즉시 자동 재생되는 전용 세레모니 애니메이션"의 확실한 선례는 찾지 못했다. 폴가이즈는 텍스트/배지로 처리하고, 스텀블가이즈는 "플레이어가 자유 시간에 직접 트리거하는 이모트"로 처리한다. 즉 **우리가 "통과 즉시 자동 세레모니"를 설계하면 업계 평균보다 한 걸음 더 들어간 것**이라 레퍼런스가 깔아 둔 안전한 전례는 없다 — 대신 리스크 자체는 낮다(길이·타이밍만 서버 진행과 분리해 통제하면 됨).

---

## 5. 가격 참고 (`docs/REFERENCE-roblox-monetization.md` 보완)

- 로블록스 공식 이모트 마켓플레이스 개별가: **1~80 R$**대.
- Royale High류 UGC 댄스 이모트: **50~55 R$**가 표준 구간.
- 우리 게임 맥락: 스킨 일반 등급이 이미 **29 R$**로 확정돼 있다(GDD 9.2). 이모트는 스킨보다 가벼운 콘텐츠(히트박스·몸 구조 영향 없음, 순수 애니메이션)이므로, **스킨 일반가와 같거나 낮은 선(19~29 R$)**이 로블록스 시세와도, 우리 기존 가격 사다리와도 맞는다.

---

## 출처 (확인일 2026-10-09)
- Roblox Creator Docs, "Emotes" — https://create.roblox.com/docs/characters/emotes (원문)
- DevForum, "Avatar Creators Can Publish and Sell Emotes on Marketplace" (2025-08-07) — https://devforum.roblox.com/t/avatar-creators-can-publish-and-sell-emotes-on-marketplace/3866987 (원문)
- DevForum, "How do I make my emote stop while walking?" 등 다수 애니메이션 우선순위 스레드 — https://devforum.roblox.com/t/how-do-i-make-my-emote-stop-while-walking/268510 , https://devforum.roblox.com/t/can-anybody-explain-me-animation-priority-coreactionmovementidle/1481376 (검색 요약)
- Gfinity, "Roblox: Brookhaven RP - How to Use Emotes" — https://www.gfinityesports.com/article/roblox-brookhaven-rp-how-to-use-emotes (검색 요약)
- RobloxDen, "Brookhaven: All Emotes (2026)" — https://robloxden.com/game-guides/brookhaven-rp/brookhaven-all-emotes (검색 요약)
- Rolimons 매물 다수(Royale High Dance류, 50~55 R$) — https://www.rolimons.com/item/89740891976668 등 (검색 요약, 실거래 매물가)
- Stumble Guys 공식, 이모트/타운트 안내 — https://www.stumbleguys.com/ , https://sgmody.com/emotes/ (검색 요약)
- Steam Community, Stumble Guys "Pay-to-Win?" 토론 — https://steamcommunity.com/app/1677740/discussions/0/3819662797149855784/ (검색 요약)
- PCGamesN, "Epic says 2 Milly's Fortnite lawsuit is 'at odds with free speech'" — https://www.pcgamesn.com/fortnite/fortnite-dance-lawsuits (원문 인용 확인)
- The Hollywood Reporter, "'Fortnite' Legal Dance Battles Paused Following Supreme Court Ruling" — https://www.hollywoodreporter.com/business/business-news/fortnite-legal-dance-battles-paused-supreme-court-ruling-1193167/ (원문 인용 확인)
- win.gg, "Fortnite dance lawsuit dropped by Alfonso Ribeiro, 2 Milly" — https://win.gg/news/fortnite-dance-lawsuit-dropped-by-alfonso-ribeiro-2-milly/ (검색 요약)
- Comicbook.com, "'Fortnite' Lawsuits Dropped by Alfonso Ribeiro, Orange Shirt Kid, and Others" — https://comicbook.com/gaming/news/fortnite-lawsuits-dropped-by-alfonso-ribeiro-orange-shirt-kid/ (검색 요약)
- Fall Guys Wiki, "Qualified Banner" / "Final" — https://fallguysultimateknockout.fandom.com/wiki/Qualified_Banner , https://fallguysultimateknockout.fandom.com/wiki/Final (검색 요약, 본문 일부 402로 막힘)
- 기존 조사 재사용: `docs/REFERENCE-roblox-monetization.md`(가격 시세, 2026-10-08)
