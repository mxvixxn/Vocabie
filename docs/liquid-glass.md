# Wordie — Liquid Glass 적용 노트

- **날짜**: 2026-07-27
- **배포 타깃**: iOS 26.0 (Moodie Sky 26.4 / Fitie 26.0 과 같은 계열)

## 원칙

Moodie Sky 설계 문서의 비목표를 그대로 승계한다:

> 커스텀 유리 바(`.ultraThinMaterial` 등) 직접 제작 금지. 순정보다 열등하고 OS 업데이트마다 깨짐.

초기 Wordie MVP는 `cardSurface()`라는 `.ultraThinMaterial` 래퍼를 **모든 카드에** 둘렀다. 이번 작업에서 전부 걷어냈다.

### 층 분리 (이 디자인의 핵심)

| 층 | 대상 | 재질 |
|---|---|---|
| **콘텐츠** | 단어, 뜻, 단어 목록 | **재질 없음.** 배경 위에 직접 |
| **조작** | 진행 알약, 선택지 패널, 버튼 | Liquid Glass |

단어 뒤에 유리를 깔면 배경이 비쳐 들어와 가독성이 떨어진다. 단어 학습 앱에서 가장 피해야 할 것이라 콘텐츠 층에는 재질을 쓰지 않는다.

### 화면 구조

```
┌─────────────────────┐
│  ◯ 유리 알약 (떠 있음) │  ← 닫기 · 진행바 · 카운트
├─────────────────────┤
│                     │
│      declare        │  ← 재질 없음. 단어만
│                     │
├─────────────────────┤
│ ╭─────────────────╮ │
│ │ 유리 패널 (떠 있음) │ │  ← 선택지 / 입력 / 버튼
│ ╰─────────────────╯ │
└─────────────────────┘
```

하단 패널은 화면 바닥에 **붙이지 않는다.** 사방에 여백을 두고 띄워야 "조작하는 물건"으로 읽힌다.

## 빌드 시 확인할 것

이 코드는 Linux 컨테이너에서 작성돼 **컴파일 검증을 못 했다.** iOS 26 SDK 시그니처가 아래와 다르면 고쳐야 한다. 유리 관련 API는 두 파일에만 모여 있다.

### `Support/Theme.swift` — `GlassSurface`

```swift
content.glassEffect(glass, in: Capsule(style: .continuous))
// tint:
Glass.regular.tint(color.opacity(0.16))
```

확인 사항:
- `View.glassEffect(_:in:)` 시그니처
- `Glass.regular` / `.tint(_:)` 존재 여부
- tint가 없거나 다르면 `GlassSurface.glass`에서 `.regular`만 반환하도록 한 줄 수정

### `Views/StudyChrome.swift` — `StudyScaffold`

```swift
GlassEffectContainer(spacing: 20) { ... }
```

확인 사항:
- `GlassEffectContainer(spacing:)` 이니셜라이저
- 안 되면 컨테이너를 벗기고 `VStack`만 남겨도 동작한다 (유리 간 모프 전환만 사라짐)

### 아직 안 붙인 것

`.glassEffectID(_:in:)` + `@Namespace` 를 쓰면 정답 선택 시 패널이 물방울처럼 늘어났다 합쳐지는 전환이 붙는다. 기본 동작 확인 후 추가할 것.

## 이번에 같이 고친 것

1. **스펠 키보드 대응** — 키보드가 화면 40%를 먹어 단어가 짓눌리던 문제.
   포커스 시 상단 알약이 얇아지고(`compactPill`), 안내 문구·메모가 숨고(`showsChrome`), 단어 크기가 34 → 30으로 줄어든다.
2. **긴 뜻 대응** — 리콜 선택지에 `lineLimit(2)` + `minimumScaleFactor(0.8)`. 뜻이 길어도 패널이 부풀어 단어를 밀어내지 않는다.
3. **암기 카드 은유 복구** — 유리를 걷어내며 사라진 "넘길 물체" 감각을, 단어 뒤 흐린 카드 두 장(`WordStage.stacked`)으로 되살렸다.
4. **오답 피드백 정의** — 클래스카드 철학대로 ✗ 와 빨강을 쓰지 않는다. 고른 오답은 조용히 흐려지고 정답만 초록으로 켜진다. 햅틱도 `.rigid` → `.light`(`Haptics.nudge`)로 낮췄다.
5. **모드 색 반영** — 유리에 암기/리콜/스펠 색을 16% 만 물들여 모드 전환이 드러나게 했다.

## 접근성

설정 → 손쉬운 사용 → **투명도 줄이기**를 켠 사용자에게는 시스템이 유리를 자동으로 불투명 처리한다. 순정 `glassEffect`를 쓰는 이유 중 하나다. 커스텀 재질로 만들면 이 대응이 깨진다.

---

# 발음 듣기 (TTS)

`Wordie/Audio/Speaker.swift` — `AVSpeechSynthesizer` 기반. 애플 번역·VoiceOver와 **같은 시스템 음성**을 쓴다. 무료·오프라인·서버 불필요.

## 무음 스위치 대응

기본 상태에서는 합성 음성이 벨소리 스위치를 따라간다. 즉 **무음 모드면 아무 소리도 안 난다.** 이걸 뚫는 게 오디오 세션 카테고리다.

```swift
try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
try session.setActive(true)
```

- `.playback` — 무음 스위치를 무시하고 재생
- `.duckOthers` — 배경 음악을 끄지 않고 잠깐 줄임 (음악 들으며 공부 가능)
- 발화가 끝나면 `setActive(false, options: [.notifyOthersOnDeactivation])`로 세션을 놓아줘야 음악 볼륨이 원래대로 돌아온다

## 음성 품질

기본 음성은 평범하다. 사용자가 **설정 → 손쉬운 사용 → 음성 콘텐츠**에서 향상된/프리미엄 음성을 받아두면 `Speaker.bestVoice(for:)`가 자동으로 그걸 고른다 (품질 premium > enhanced > default 순).

`Speaker.hasUpgradedVoice(for:)`로 업그레이드 음성 보유 여부를 알 수 있다. 아직 UI에 안 붙였다 — 나중에 "더 자연스러운 발음 받기" 안내에 쓸 것.

## 한계

단어 하나만 읽히면 문맥이 없어 동형이의어를 틀리게 읽는다: `read`, `lead`, `live`, `bow`, `tear`. TTS의 구조적 한계라 우회가 어렵다. 해당 단어는 메모 필드에 발음을 적어두는 정도가 현실적이다.

## 붙인 위치

- **암기** — 영단어가 보이는 면일 때만 스피커 버튼 노출. 카드 넘길 때 자동 재생 (`@AppStorage("autoSpeak")`, 기본 켜짐, 단어장 메뉴에서 토글)
- **스펠** — 정답 공개 시 (뜻→단어 방향일 때만)
- **단어 목록** — 각 행에 스피커 버튼
- **리콜** — 안 붙임. 4지선다 중 정답을 소리로 알려주면 문제가 성립하지 않는다

---

# 간격 반복 (Spaced Repetition)

`Wordie/Study/Scheduler.swift`

## 왜 필요한가

기존 `StudySession`의 반복은 **세션 안에서만** 돈다. 오늘 60개를 다 맞히고 끝내면 사흘 뒤엔 잊는다. 날짜 기반 복습이 붙어야 "오늘 외웠다"가 "다음 달에도 안다"가 된다.

## 자기 평가를 안 받는 이유

Anki는 사용자에게 Again/Hard/Good/Easy를 직접 고르게 한다. Wordie는 그럴 필요가 없다 — 리콜·스펠이 **몇 번 만에 맞혔는지** 이미 객관적으로 안다. 자기 평가보다 나은 신호다.

```
세션 중 틀린 횟수 → 등급
  0회  → recalled   (첫 시도에 맞음)
  1회  → struggled  (한 번 틀리고 맞음)
  2회+ → forgot     (반복해서 틀림, 또는 힌트 사용)
```

## 스케줄 규칙 (SM-2 변형)

| 등급 | 간격 | ease |
|---|---|---|
| `recalled` | 0 → 1일 → 3일 → 이후 `간격 × ease` | +0.05 |
| `struggled` | `간격 × 1.2` (거의 제자리) | −0.05 |
| `forgot` | **1일로 리셋** | −0.20 |

- ease 범위 **1.3 ~ 2.8** — 최저가 있어 어려운 단어도 무한히 나빠지지 않는다
- 간격 상한 **180일** — 반년 넘게 미룰 이유가 없다
- 복습일은 해당 날짜의 **자정 기준**. "내일 복습"이 공부한 시각과 무관하게 내일 아침부터 열린다

검증한 곡선 (매번 맞히는 경우):

```
1회차   1일    ease 2.55
2회차   3일    ease 2.60
3회차   8일    ease 2.65
4회차  21일    ease 2.70
5회차  56일    ease 2.75
6회차 154일    ease 2.80   → 이후 180일 고정
```

## 암기 모드는 스케줄을 만들지 않는다

암기(플래시카드)는 **노출**이지 **인출**이 아니다. 보기만 한 걸로 복습 간격을 늘리면 실제로 아는 것보다 앞서 나가게 된다. 그래서 `StudySession.grade`에서 `mode != .memorize` 일 때만 `Scheduler.apply`를 호출한다.

## UI

- **홈 상단 배너** — 복습할 카드가 있을 때만 나타남. 전체 단어장을 가로질러 모은다
- **단어장 행 배지** — 단어장별 복습 대기 수
- **`ReviewStartView`** — 리콜/스펠 중 선택. 암기는 제외 (등급을 못 매기므로)
- **자꾸 틀리는 단어** — `lapses >= 4` 이면 `isLeech`. 복습 화면에서 따로 알려줌

## 한 번도 학습하지 않은 카드

`dueDate == nil` 이면 복습 대상이 아니다. 새로 넣은 단어는 단어장에서 한 번 학습해야 스케줄에 편입된다. 의도한 동작 — 첫 만남은 복습이 아니다.

## 테스트

테스트 타깃이 아직 없다. `Scheduler.next(interval:ease:grade:)` 는 순수 함수이므로 타깃을 추가하면 바로 단위 테스트할 수 있다. 위 곡선은 동일 로직을 스크립트로 재현해 확인했다.

---

# 파서 — 영어/한글 경계로 자르기

`Wordie/Import/WordParser.swift`

## 고친 버그

초기 `autoSplit`은 **쉼표를 대시보다 먼저** 검사했다.

```swift
if line.contains(",") { return csvRow(line) }    // ← 여기서 먼저 걸림
if line.contains(" - ") { ... }
```

한국어 뜻에는 쉼표가 흔하다. `hold on - 기다려, 잠깐만` 은 쉼표에서 먼저 쪼개져 단어가 `"hold on - 기다려"` 가 됐다. 하이픈도 `" - "`(양쪽 공백)만 인식해서 `hold on-기다려` 는 아예 못 잡았다.

## 해법 — 스크립트 경계

구두점으로 자르는 대신 **첫 한글 문자**에서 자른다. 영↔한 단어장에서는 이게 가장 신뢰할 수 있는 신호다.

- 단어 안의 하이픈이 살아남는다 (`well-known`)
- 뜻 안의 쉼표가 살아남는다 (`기다려, 잠깐만`)
- 구분자를 아예 안 써도 갈린다 (`well-known 잘 알려진`)
- 문장도 된다 (`That's fine with me. - 난 괜찮아`)

단어 뒤에 남은 구분자(` - `, `:`, `,`, `|` 등)는 **끝에서만** 잘라내므로 단어 내부 하이픈은 보존된다.

### 뜻을 여는 문장부호 예외

한국어 뜻은 첫 글자 앞에 부호가 붙는 경우가 많다. 이 부호들은 **뜻에 속하므로** 경계를 그 앞까지 밀어낸다. 안 그러면 경계가 괄호 *안*에 떨어져 단어에 `(` 가 남는다.

- 물결표 — `~을 복습하다`
- 괄호 한정어 — `(놓여)있다`, `(온도 단위인)도`

```
brush up on ~을 복습하다   →  'brush up on' | '~을 복습하다'
lie - (놓여)있다, 눕다      →  'lie'         | '(놓여)있다, 눕다'
degree - (온도 단위인)도    →  'degree'      | '(온도 단위인)도, 정도'
```

단어 **뒤**의 괄호는 영향받지 않는다. `deposit (n) - 예금` 은 `'deposit (n)' | '예금'` 으로 갈린다 — 되감기는 첫 한글 **바로 앞** 문자부터라 사이에 공백이 있으면 멈춘다.

## 우선순위

```
1. 탭          — 스프레드시트에서 온 명시적 열 구분. 최우선
2. 스크립트 경계 — 영↔한이면 여기서 끝난다
3. 쉼표 / 대시 / 콜론 / 등호 / 넓은 공백 — 영↔한이 아닌 단어장용
```

## 대시 선택 시

사용자가 `대시 -` 를 직접 고르면:
1. 공백 있는 대시(` - `, ` – `, ` — `)를 먼저 시도 — 명확하므로
2. 없으면 **마지막** 하이픈에서 자른다. 구분자는 두 열 사이에 있고, 하이픈 단어(`well-known`)는 앞쪽 하이픈을 지킨다

## 검증

동일 로직을 스크립트로 재현해 확인했다. 사용자의 실제 노션 데이터(번호 목록 + ` - ` 구분 + 괄호 한정어 + 물결표) 10줄이 전부 올바르게 갈렸고, 하이픈 단어·쉼표 포함 뜻·문장·마크다운 불릿·탭·em dash·단어 뒤 괄호 회귀 케이스도 통과했다.

`WordParser.parse` 는 순수 함수이므로 테스트 타깃이 생기면 그대로 단위 테스트로 옮길 것.

---

# 코드 재점검에서 찾은 버그 (2026-07-27)

컴파일을 못 하는 환경이라 정적으로 훑으며 찾은 것들. 전부 수정했다.

## 1. SwiftData — 관계를 insert 전에 설정 ⚠️ 가장 유력한 "안 되는" 원인

```swift
vocab.set = set        // ← 아직 컨텍스트에 없는 객체
context.insert(vocab)
```

컨텍스트에 등록되지 않은 객체를 이미 저장된 객체에 연결하면 SwiftData에서 관계가 조용히 누락될 수 있다. **insert를 먼저 하고 관계를 잇도록** 순서를 뒤집었다.

- `ImportWordsView.commit()` — 대량 추가한 단어가 단어장에 안 붙는 증상
- `EditWordView.save()` — 단어 하나 추가도 동일

## 2. 삭제 후 사라진 객체를 렌더링

`SetDetailView`는 `@Bindable var set` 을 들고 있어서, 화면에 떠 있는 상태로 `context.delete(set)` 하면 내비게이션 타이틀·단어 목록이 파기된 객체를 한 번 더 읽는다. 크래시 위험.

→ `dismiss()` 를 **먼저** 하고, 화면이 빠진 뒤 삭제하도록 바꿨다. `RootView` 쪽도 `pendingDeletion` 을 먼저 nil 로 비운 다음 삭제한다.

## 3. `splitSeparated` 가 반쪽짜리 행을 반환

```swift
guard !term.isEmpty else { return nil }   // meaning 검사가 없었다
```

뜻이 비어도 행을 만들어 반환했다. `autoSplit` 이 그 시점에 멈춰버려서 **다음 구분자를 시도하지 못하고 줄이 통째로 사라졌다.** 두 쪽 다 검사하도록 고쳤다.

## 4. `.constant` 바인딩으로 띄운 알림

```swift
.alert(..., isPresented: .constant(importError != nil))
```

SwiftUI가 스스로 닫을 수 없는 바인딩이라 알림이 화면에 남을 수 있다. 정상적인 양방향 `Binding` 으로 교체.

## 5. 경고 — `csvRow` 의 `var chars`

한 번도 변경되지 않는데 `var` 였다. `let` 으로.

---

# 단어장 삭제 · 이름 변경

로드맵 2-1 항목. 지금까지 **만든 단어장을 지울 방법이 없었다.**

- **홈** — **옆으로 스와이프** (Moodie Sky 다이어리 목록과 동일 패턴)
  - 왼쪽으로 밀기(trailing) → 삭제. `allowsFullSwipe: true` 라 끝까지 밀면 바로 확인 창
  - 오른쪽으로 밀기(leading) → 이름 변경. `.tint(.blue)`
- **단어장 상세** — 우측 상단 `⋯` 메뉴 → 이름 변경 / 삭제
- 삭제는 **확인 다이얼로그**를 거친다. 단어 수를 함께 보여주고 되돌릴 수 없음을 명시
- `Vocab` 에 cascade 규칙이 걸려 있어 단어와 학습 기록이 함께 삭제된다

툴바 아이콘을 `plus.circle.fill` → `ellipsis.circle.fill` 로 바꿨다. 이제 추가 말고도 다른 동작이 들어가서.

## 스와이프 삭제 — Moodie Sky 패턴 이식

`.swipeActions` 는 `List` 안에서만 동작한다. 홈 화면이 `ScrollView` + `LazyVStack` 이었으므로 `List` 로 바꾸고, 카드가 그라데이션 위에 떠 있던 모양은 그대로 유지했다.

```swift
.listStyle(.plain)
.scrollContentBackground(.hidden)   // 배경 그라데이션이 비치도록
```

행 여백은 Moodie Sky 다이어리 목록과 동일하게 맞췄다 (`plainRow()`):

```swift
.listRowBackground(Color.clear)
.listRowSeparator(.hidden)
.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
```

### 햅틱도 동일하게

| 시점 | 햅틱 | Moodie Sky 대응 |
|---|---|---|
| 스와이프해서 삭제/이름변경 누름 | `Haptics.selection()` — `UISelectionFeedbackGenerator` | `triggerSelectionHaptic()` |
| 삭제 확정 | `Haptics.intenseError()` — `.error` **두 번, 0.1초 간격** | `triggerIntenseErrorHaptic()` |

둘 다 `prepare()` 를 먼저 호출한다. 삭제 확정의 이중 진동이 "되돌릴 수 없다"는 감각을 만드는 부분이라 그대로 옮겼다.

행 등장·삭제에는 `.transition(.move(edge: .top).combined(with: .opacity))` 와 `withAnimation` 을 걸어 목록이 부드럽게 접히게 했다.

### 남은 것

`List` 안의 `NavigationLink` 라 행 오른쪽에 시스템 **디스클로저 셰브런(›)** 이 붙는다. 카드형 행과 어울리는지는 실제 빌드에서 확인 필요. 거슬리면 `NavigationLink` 대신 탭 제스처 + `navigationDestination(isPresented:)` 로 바꾸면 된다 (Moodie Sky가 쓰는 방식).
