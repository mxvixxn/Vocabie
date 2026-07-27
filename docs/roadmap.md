# Wordie 작업 계획

_2026-07-27 기준 · 커밋 4개 · Swift 파일 20개 · **빌드 미검증**_

---

## 지금 상태

| 커밋 | 내용 | 검증 |
|---|---|---|
| `e6cfa8e` | MVP — 암기·리콜·스펠 3모드, 대량 입력 | ❌ |
| `cf764ce` | Liquid Glass 재설계, 배포 타깃 iOS 26 | ❌ |
| `46c41bb` | 발음 듣기 (TTS, 무음 모드 대응) | ❌ |
| `d980d85` | 간격 반복 (SM-2 변형) | 로직만 ✅ |

전부 리눅스 컨테이너에서 작성돼 **한 번도 컴파일된 적이 없다.** 간격 반복의 스케줄 곡선만 동일 로직을 스크립트로 재현해 확인했다.

여기서 기능을 더 쌓으면 안 된다. 에러가 한꺼번에 터지면 어느 커밋이 원인인지 가려내기 어려워진다.

---

## 1단계 — 빌드 검증 (맥 앞에서 제일 먼저)

```bash
cd ~/.../Wordie
xcodebuild -project Wordie.xcodeproj -scheme Wordie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build 2>&1 | tail -40
```

에러는 아래 순서로 뜰 가능성이 높다. 각 항목에 **미리 정해둔 대응**이 있으니 그대로 처리하면 된다.

### 1-1. Liquid Glass API — 위험도 높음

**어디**: `Support/Theme.swift`의 `GlassSurface`

```swift
content.glassEffect(glass, in: Capsule(style: .continuous))
Glass.regular.tint(color.opacity(0.16))
```

| 증상 | 대응 |
|---|---|
| `glassEffect` 시그니처 불일치 | 자동완성으로 실제 시그니처 확인 후 두 줄(`case .capsule` / `case .rounded`)만 수정 |
| `Glass` 타입이 없음 / `.tint` 없음 | `GlassSurface.glass`가 `.regular`만 반환하도록 축소. 모드별 색조만 사라진다 |
| 전부 안 됨 | `.background(.regularMaterial, in: shape)`로 임시 대체하고 유리는 나중에. **레이아웃은 그대로 유지된다** |

**어디**: `Views/StudyChrome.swift`의 `StudyScaffold`

```swift
GlassEffectContainer(spacing: 20) { ... }
```

| 증상 | 대응 |
|---|---|
| 이니셜라이저 불일치 | 컨테이너를 벗기고 안쪽 `VStack`만 남긴다. 유리 간 모프 전환만 없어지고 나머지는 동작 |

### 1-2. `Speaker`의 `@Observable` + `NSObject` — 위험도 중간

**어디**: `Audio/Speaker.swift`

`AVSpeechSynthesizerDelegate` 때문에 `NSObject`를 상속하면서 `@Observable`을 같이 붙였다. 충돌하면:

1. `@Observable` 제거
2. `isSpeaking`을 쓰는 곳은 `SpeakButton` 하나뿐 — 아이콘 애니메이션 포기하고 정적 아이콘으로
3. 발음 재생 자체는 영향 없음

### 1-3. 나머지 — 위험도 낮음

- `symbolEffect(.variableColor.iterative, isActive:)` — iOS 17+ API, 문제없을 것
- ViewBuilder 안의 `let due = set.dueCount()` (`RootView.SetRow`) — 최신 SwiftUI에서 허용됨
- `StudyScaffold`의 트레일링 클로저 2개 (`{ stage } panel: { ... }`) — 문법상 유효
- SwiftData 필드 5개 추가 — 배포 전이라 마이그레이션 이슈 없음

### 1-4. 빌드 성공 후 눈으로 확인할 것

- [ ] 하단 유리 패널이 화면 바닥에서 **떠 있는지** (붙어 있으면 여백 설정 문제)
- [ ] 단어 뒤에 유리가 **없는지** (있으면 재설계가 덜 반영된 것)
- [ ] **스펠에서 키보드를 올렸을 때** 단어가 안 짓눌리는지 ← 제일 중요
- [ ] 무음 스위치 켠 상태에서 발음이 들리는지
- [ ] 리콜에서 오답 골랐을 때 빨강·✗ 없이 조용히 넘어가는지
- [ ] 다크 모드
- [ ] 설정 → 손쉬운 사용 → **투명도 줄이기** 켜고 유리가 불투명해지는지

---

## 2단계 — 빠진 기본기

기능을 더 얹기 전에 메워야 할 구멍들. 전부 작은 작업이다.

### 2-1. 단어장 삭제·이름 변경이 없다 ← 가장 급함

지금 **만든 단어장을 지울 방법이 없다.** 오타 난 단어장도 영원히 남는다. 목록에서 스와이프 삭제 + 상세에서 이름 편집.

### 2-2. 내보내기가 없다

가져오기(CSV·엑셀·텍스트·마크다운)는 되는데 **빼낼 수가 없다.** 기기를 잃으면 수백 개 단어가 사라진다. 최소한 CSV 내보내기는 있어야 한다. (Moodie Sky의 백업 코드가 참고가 된다)

### 2-3. 단어 검색

단어장이 수백 개가 되면 목록을 스크롤로 훑는 건 무리. `.searchable` 한 줄이면 된다.

### 2-4. 앱 아이콘

지금은 빈 플레이스홀더. Moodie Sky처럼 Icon Composer로 만들고, "ie" 패밀리룩을 맞춘다.

### 2-5. 테스트 타깃

없다. `Scheduler.next(interval:ease:grade:)`와 `WordParser.parse`, `SpellNormalizer.matches`는 전부 순수 함수라 타깃만 추가하면 바로 테스트가 붙는다. 이 셋이 앱의 두뇌라 회귀가 제일 아픈 곳이다.

---

## 3단계 — 간격 반복 완성하기

### 복습 알림 ← 이게 없으면 간격 반복은 반쪽짜리다

지금 스케줄러는 "이 단어는 3일 뒤에 봐야 한다"를 계산해 둔다. **그런데 3일 뒤에 그걸 알려줄 방법이 없다.** 앱을 스스로 열지 않으면 스케줄은 아무 의미가 없다.

- 매일 정해진 시각에 "복습할 단어 N개" 알림
- 복습할 게 없는 날은 **보내지 않는다** (Moodie Sky의 `skipsReminderAfterTodayEntry`와 같은 발상)
- 방해 금지 시간 설정
- 앱 아이콘 배지에 복습 대기 수

`UserNotifications` + Moodie Sky에 이미 있는 알림 로직을 참고하면 빠르다.

### 위젯 (그다음)

잠금화면·홈화면에 오늘 복습할 단어 수, 또는 오늘의 단어 하나. Moodie Sky에 `MoodieSkyWidgets` 타깃이 있으니 구조를 그대로 가져온다.

---

## 4단계 — 그 이후

우선순위 순.

| 항목 | 메모 |
|---|---|
| **통계 화면** | 자주 틀리는 단어, 학습 기록, 요일별 리듬. `lapses`·`timesWrong` 데이터가 이미 쌓이고 있다 |
| **테스트 모드** | 클래스카드의 마무리 시험. 객관식+주관식 혼합, 점수와 오답 노트 |
| **CloudKit 동기화** | 아이폰↔아이패드. SwiftData가 CloudKit을 지원해서 설정 위주 작업 |
| **매칭게임** | 서버 불필요. 우선순위는 낮다고 이야기됨 |
| **원어민 발음** | Wiktionary(CC 라이선스) 또는 Merriam-Webster API. 네이버 사전은 약관·저작권 문제로 제외 |

---

## 결정해 둔 것 (다시 논의하지 않기)

- **유리는 조작 층에만.** 단어·뜻·목록에는 재질을 쓰지 않는다
- **커스텀 유리 금지.** 순정 `glassEffect`만. (Moodie Sky 설계 문서 승계)
- **하단 패널은 바닥에서 띄운다.** 붙이면 화면의 일부로 읽힌다
- **오답에 빨강·✗ 쓰지 않는다.** 조용히 흐려지고 정답만 켜진다
- **암기 모드는 복습 스케줄을 만들지 않는다.** 노출이지 인출이 아니므로
- **자기 평가를 받지 않는다.** 몇 번 만에 맞혔는지로 자동 채점
- **네이버 등 사전 음성 무단 사용 안 한다.** 약관·저작권 위반
