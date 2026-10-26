import SwiftUI
import SwiftData

/// The hub for one set: pick a study mode or manage its words.
struct SetDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @Bindable var set: VocabSet

    @AppStorage("autoSpeak") private var autoSpeak = true
    /// When on, 리콜 / 스펠 draw cards in random order instead of set order.
    @AppStorage("studyShuffle") private var shuffleStudy = false

    @State private var direction: StudyDirection = .termToMeaning
    @State private var showingImport = false
    @State private var showingAddOne = false
    @State private var activeMode: StudyMode?
    @State private var showingRename = false
    @State private var showingMove = false
    @State private var showingWordOrder = false
    @State private var confirmingDelete = false
    @State private var draftTitle = ""

    /// When on, finishing a session offers to carry straight on to what follows.
    @AppStorage("continueToNext") private var continueToNext = true

    // Round (묶음) study — the set is studied 10 cards at a time.
    private let roundSize = 10
    @State private var selectedRound = 0
    // Resume flow — offered for all three modes.
    @State private var showingResumeDialog = false
    @State private var pending: PendingStudy?
    @State private var resumeProgress: StudyProgress?

    /// A launch waiting on the 이어서 / 처음부터 question.
    private struct PendingStudy {
        let mode: StudyMode
        /// The 묶음 the learner left this mode on.
        let round: Int
        /// Progress saved part-way through that 묶음, if any.
        let progress: StudyProgress?
    }

    /// What the open study cover is working on. Normally this set's selected 묶음, and
    /// "이어서" moves it on to the next 묶음 of the same set without leaving the cover.
    @State private var target: StudyTarget?
    /// Bumped on every hand-off so SwiftUI builds a fresh study view (and a fresh
    /// session) instead of reusing the finished one.
    @State private var studySeq = 0

    private struct StudyTarget {
        let set: VocabSet
        let round: Int
    }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if set.words.isEmpty {
                        emptyWords
                    } else {
                        directionPicker
                        studyOptions
                        modeCards
                        wordListSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(set.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Grouped the way the learner thinks about the screen: put words in,
                    // set how it behaves, take it out, then manage the set itself. The
                    // wording is deliberately plain — every menu in the app says 추가 /
                    // 변경 / 이동 / 보관 / 삭제 and nothing longer.
                    Section {
                        Button { showingAddOne = true } label: {
                            Label("단어 추가", systemImage: "plus")
                        }
                        Button { showingImport = true } label: {
                            Label("붙여넣기로 추가", systemImage: "doc.on.clipboard")
                        }
                    }
                    Section {
                        Toggle(isOn: $autoSpeak) {
                            Label("자동 발음", systemImage: "speaker.wave.2")
                        }
                        Button { showingWordOrder = true } label: {
                            Label("순서 변경", systemImage: "arrow.up.arrow.down")
                        }
                        .disabled(set.wordCount < 2)
                        Button { exportCSV() } label: {
                            Label("CSV 내보내기", systemImage: "square.and.arrow.up")
                        }
                        .disabled(set.words.isEmpty)
                    }
                    Section {
                        Button {
                            draftTitle = set.title
                            showingRename = true
                        } label: {
                            Label("이름 변경", systemImage: "pencil")
                        }
                        Button { showingMove = true } label: {
                            Label("단어장 이동", systemImage: "folder")
                        }
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.tint)
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            ImportWordsView(set: set)
        }
        .sheet(isPresented: $showingAddOne) {
            EditWordView(set: set, word: nil)
        }
        .sheet(item: $sharingCSV) { file in
            ShareSheet(items: [file.url])
        }
        .sheet(isPresented: $showingMove) {
            MoveSetView(set: set)
        }
        .sheet(isPresented: $showingWordOrder) {
            WordOrderView(set: set)
        }
        .alert("이름 변경", isPresented: $showingRename) {
            TextField("세트 이름", text: $draftTitle)
            Button("취소", role: .cancel) { }
            Button("저장") { renameSet() }
        }
        .confirmationDialog(
            "‘\(set.title)’을(를) 삭제할까요?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deleteSet() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("단어 \(set.wordCount)개와 학습 기록이 함께 사라져요. 되돌릴 수 없어요.")
        }
        .fullScreenCover(item: $activeMode) { mode in
            // Keyed on the hand-off counter: "이어서" swaps the material underneath a
            // cover that never closed, and only a new identity rebuilds the session.
            studyView(for: mode).id(studySeq)
        }
        .onChange(of: activeMode) { _, mode in
            if mode == nil {
                target = nil
                resumeProgress = nil
                syncSelectedRound()
            }
        }
        // An alert, not a confirmation dialog: the dialog anchors itself to a source
        // view and its tail ended up pointing at the 암기 card no matter which mode
        // was tapped. A centred alert belongs to nothing, so it can't mislead.
        .alert("이어서 학습할까요?", isPresented: $showingResumeDialog) {
            if let pending {
                Button(resumeButtonTitle(pending)) {
                    start(pending.mode, round: pending.round, progress: pending.progress)
                }
                Button(alternativeTitle(pending), role: .destructive) {
                    // The alternative is always "the 묶음 the screen is showing, from the
                    // top". When that is the same 묶음 being offered, this reads as
                    // 처음부터; when the learner has picked a different one, it has to
                    // take them there — offering to restart a 묶음 they didn't choose
                    // would leave the picked one unreachable.
                    StudyProgressStore.clear(progressKey(pending.mode,
                                                         StudyTarget(set: set, round: currentRound)))
                    start(pending.mode, round: currentRound, progress: nil)
                }
            }
            Button("취소", role: .cancel) { pending = nil; resumeProgress = nil }
        } message: {
            // Name the mode and the 묶음 — the learner needs to know *this* is the
            // 스펠 they tapped, and where it would drop them.
            if let pending {
                Text("‘\(pending.mode.korean)’ \(roundLabel(pending.round))에서 멈췄어요.")
            }
        }
        .onAppear(perform: syncSelectedRound)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 8) {
            // Progress is per direction: 영단어 → 뜻 and 뜻 → 영단어 are separate skills
            // and now carry separate stars, so the bar follows the picker below it.
            Text("\(set.wordCount)단어 · \(direction.label(for: set.language)) \(Int(set.masteryProgress(for: direction) * 100))% 완료")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ProgressView(value: set.masteryProgress(for: direction))
                .tint(Theme.tint)
                .animation(.easeInOut(duration: 0.25), value: direction)
        }
        .padding(16)
        .glassPanel()
        .padding(.top, 8)
    }

    private var directionPicker: some View {
        Picker("방향", selection: $direction) {
            ForEach(StudyDirection.allCases) { d in
                Text(d.label(for: set.language)).tag(d)
            }
        }
        .pickerStyle(.segmented)
    }

    private var modeCards: some View {
        VStack(spacing: 12) {
            // 스펠 is missing for a script with no spelling to type — see
            // `VocabSet.availableModes`. A one-line note stands in for it so the
            // absence reads as deliberate rather than as a bug.
            ForEach(set.availableModes) { mode in
                Button {
                    Haptics.soft()
                    launch(mode)
                } label: {
                    ModeCard(mode: mode)
                }
                .buttonStyle(.plain)
            }
            if !set.language.supportsSpell {
                Text(set.language.spellUnavailableReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: Round (묶음) + shuffle

    /// Any set's cards split into rounds of `roundSize`. 10 or fewer is one round.
    private func rounds(of target: VocabSet) -> [[Vocab]] {
        let words = target.orderedWords
        guard words.count > roundSize else { return [words] }
        return stride(from: 0, to: words.count, by: roundSize).map {
            Array(words[$0 ..< min($0 + roundSize, words.count)])
        }
    }

    private var rounds: [[Vocab]] { rounds(of: set) }

    /// The 묶음 picker's "전체" entry: the whole set at once, no split. Stored as a
    /// round index so everything downstream — the study target, the progress key, the
    /// word list — keeps working on one type.
    private static let wholeSet = -1

    private var hasRounds: Bool { self.set.wordCount > roundSize }

    private var currentRound: Int {
        if selectedRound == Self.wholeSet { return Self.wholeSet }
        return rounds.indices.contains(selectedRound) ? selectedRound : 0
    }

    private var roundCards: [Vocab] { cards(for: currentTarget) }

    private func roundRangeLabel(_ i: Int) -> String {
        rangeLabel(rounds, i)
    }

    private func rangeLabel(_ chunks: [[Vocab]], _ i: Int) -> String {
        guard chunks.indices.contains(i) else { return "" }
        return "\(i * roundSize + 1)–\(i * roundSize + chunks[i].count)"
    }

    /// What the current selection is called, for headings and dialogs.
    private var scopeLabel: String {
        guard hasRounds else { return "전체" }
        if currentRound == Self.wholeSet { return "전체" }
        return "묶음 \(currentRound + 1) · \(roundRangeLabel(currentRound))"
    }

    /// A round is "done" once every card in it is fully mastered (3 stars).
    private func roundMastered(_ i: Int) -> Bool {
        guard rounds.indices.contains(i) else { return false }
        return rounds[i].allSatisfy { $0.starRating(for: direction) >= 3 }
    }

    private var firstUnfinishedRound: Int {
        rounds.firstIndex { round in
            !round.allSatisfy { $0.starRating(for: direction) >= 3 }
        } ?? 0
    }

    /// Land on the first unfinished round, unless the learner is mid-way through one —
    /// or has deliberately asked for 전체, which is left alone.
    private func syncSelectedRound() {
        guard selectedRound != Self.wholeSet else { return }
        if !rounds.indices.contains(selectedRound) || roundMastered(selectedRound) {
            selectedRound = firstUnfinishedRound
        }
    }

    private func progressKey(_ mode: StudyMode) -> String {
        progressKey(mode, currentTarget)
    }

    private func progressKey(_ mode: StudyMode, _ target: StudyTarget) -> String {
        "\(mode.rawValue)|\(target.set.id.uuidString)|\(target.round)"
    }

    private var currentTarget: StudyTarget { StudyTarget(set: set, round: currentRound) }

    private func cards(for target: StudyTarget) -> [Vocab] {
        guard target.round != Self.wholeSet else { return target.set.orderedWords }
        let chunks = rounds(of: target.set)
        return chunks.indices.contains(target.round) ? chunks[target.round] : []
    }

    /// What follows this chunk: the next 묶음 of the *same* set, and nothing else.
    ///
    /// Sets are independent. Rolling on into the next 세트 on the shelf meant finishing
    /// 21–25 and landing in 18–20 — material the learner never asked for, in an order
    /// that reads as random. The last 묶음 of a set is the end of the session; the
    /// finish screen offers 한 번 더 and 끝내기 there.
    private func nextTarget(after target: StudyTarget) -> StudyTarget? {
        // Studying 전체 already covered the set, so nothing follows it.
        guard target.round != Self.wholeSet,
              rounds(of: target.set).indices.contains(target.round + 1) else { return nil }
        return StudyTarget(set: target.set, round: target.round + 1)
    }

    private func label(for target: StudyTarget) -> String {
        let chunks = rounds(of: target.set)
        guard target.round != Self.wholeSet else { return "\(target.set.title) 전체" }
        return chunks.count > 1
            ? "묶음 \(target.round + 1) · \(rangeLabel(chunks, target.round))"
            : target.set.title
    }

    /// Hand the open cover over to the next chunk. Any progress already saved for it is
    /// picked up rather than overwritten — "이어서" should never quietly discard a round
    /// the learner was half way through.
    private func advance(_ mode: StudyMode, to next: StudyTarget) {
        Haptics.soft()
        resumeProgress = StudyProgressStore.load(progressKey(mode, next))
            .flatMap { $0.total > 0 && $0.clearedIDs.count < $0.total ? $0 : nil }
        if next.set.id == set.id { selectedRound = next.round }
        target = next
        StudyPlaceStore.save(round: next.round, mode: mode, setID: next.set.id)
        studySeq += 1
    }

    private var studyOptions: some View {
        HStack(spacing: 10) {
            if hasRounds { roundMenu }
            Spacer(minLength: 0)
            shuffleButton
        }
    }

    private var roundMenu: some View {
        Menu {
            ForEach(rounds.indices, id: \.self) { i in
                Button {
                    pick(round: i)
                } label: {
                    if roundMastered(i) {
                        Label("묶음 \(i + 1) (\(roundRangeLabel(i)))", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("묶음 \(i + 1) (\(roundRangeLabel(i)))")
                    }
                }
            }
            Divider()
            Button { pick(round: Self.wholeSet) } label: {
                Text("전체 (\(set.wordCount)단어)")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill").font(.caption)
                Text(scopeLabel)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.tint)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Theme.tint.opacity(0.12), in: Capsule())
        }
    }

    /// Picking a 묶음 changes what the word list below shows as well as what a mode
    /// launches with — the split is the point of the feature, so the list has to honour
    /// it. The search box, when it is open, searches within the pick.
    private func pick(round: Int) {
        Haptics.selection()
        withAnimation(.easeInOut(duration: 0.2)) { selectedRound = round }
    }

    private var shuffleButton: some View {
        Button {
            shuffleStudy.toggle()
            Haptics.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "shuffle")
                Text("랜덤")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(shuffleStudy ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                shuffleStudy ? AnyShapeStyle(Theme.tint) : AnyShapeStyle(Theme.rowFill),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    /// Launch a mode.
    ///
    /// Two things can make this a question rather than a jump: progress saved part-way
    /// through a 묶음, and a 묶음 the learner walked away from last time — 끝내기 on
    /// 묶음 5 should be waiting for them on the way back in, whichever mode they tap.
    private func launch(_ mode: StudyMode) {
        let saved = StudyPlaceStore.load(mode: mode, setID: set.id).flatMap(validRound)
        let round = saved ?? currentRound
        let progress = inProgress(mode, round: round)

        if progress != nil || (round != currentRound && !roundMastered(round)) {
            pending = PendingStudy(mode: mode, round: round, progress: progress)
            showingResumeDialog = true
        } else {
            start(mode, round: currentRound, progress: nil)
        }
    }

    /// Open a mode on a specific 묶음, and remember it as this mode's place.
    private func start(_ mode: StudyMode, round: Int, progress: StudyProgress?) {
        pending = nil
        selectedRound = round
        resumeProgress = progress
        target = StudyTarget(set: set, round: round)
        StudyPlaceStore.save(round: round, mode: mode, setID: set.id)
        activeMode = mode
    }

    /// Saved progress for a round, but only while it is worth offering — a round that
    /// was finished has nothing left to resume.
    private func inProgress(_ mode: StudyMode, round: Int) -> StudyProgress? {
        let saved = StudyProgressStore.load(progressKey(mode, StudyTarget(set: set, round: round)))
        guard let saved, saved.total > 0, saved.clearedIDs.count < saved.total else { return nil }
        return saved
    }

    /// A stored round index, if it still points at something in this set.
    private func validRound(_ round: Int) -> Int? {
        if round == Self.wholeSet { return hasRounds ? round : nil }
        return rounds.indices.contains(round) ? round : nil
    }

    private func roundLabel(_ round: Int) -> String {
        guard round != Self.wholeSet else { return "전체" }
        guard hasRounds else { return "전체" }
        return "묶음 \(round + 1) · \(roundRangeLabel(round))"
    }

    private func resumeButtonTitle(_ pending: PendingStudy) -> String {
        guard let p = pending.progress else { return "\(roundLabel(pending.round))부터" }
        return "이어서 (\(p.clearedIDs.count)/\(p.total))"
    }

    /// The other way out of the question — never just "처음부터" when what it actually
    /// starts is a different 묶음 from the one being offered.
    private func alternativeTitle(_ pending: PendingStudy) -> String {
        pending.round == currentRound ? "처음부터" : "\(roundLabel(currentRound))부터"
    }

    private var wordListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("단어 목록")
                    .font(.headline)
                if hasRounds {
                    Text(scopeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.tint.opacity(0.12)))
                }
                Spacer()
                if !wordSearch.trimmed.isEmpty {
                    Text("\(filteredWords.count) / \(roundCards.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            // A short list is faster to scan than to search.
            if roundCards.count > searchThreshold { searchField }

            // Lazy: a 300-word set would otherwise build every row up front.
            LazyVStack(spacing: 10) {
                ForEach(filteredWords) { word in
                    Button {
                        editingWord = word
                    } label: {
                        WordRow(word: word, direction: direction)
                    }
                    .buttonStyle(.plain)
                }
            }

            if filteredWords.isEmpty {
                Text("‘\(wordSearch.trimmed)’와 맞는 단어가 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            }
        }
        .sheet(item: $editingWord) { word in
            EditWordView(set: set, word: word)
        }
    }

    /// Below this many words the search box is more clutter than help.
    private let searchThreshold = 10

    /// The words the list shows: the selected 묶음 (or 전체), narrowed by the search
    /// box — term, meaning and note all match.
    private var filteredWords: [Vocab] {
        let scope = roundCards
        let query = wordSearch.trimmed.lowercased()
        guard !query.isEmpty else { return scope }
        return scope.filter {
            $0.term.lowercased().contains(query)
                || $0.meaning.lowercased().contains(query)
                || $0.note.lowercased().contains(query)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("단어 · 뜻 검색", text: $wordSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
            if !wordSearch.isEmpty {
                Button {
                    wordSearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: Theme.innerCorner, style: .continuous)
            .fill(Theme.rowFill))
    }

    @State private var editingWord: Vocab?
    @State private var wordSearch = ""
    @State private var sharingCSV: ShareableFile?

    private var emptyWords: some View {
        EmptyStateView(
            systemImage: "tray",
            title: "단어가 아직 없어요",
            message: "붙여넣기나 파일로 단어를\n한 번에 추가해 보세요.",
            actionTitle: "붙여넣기로 추가",
            actionImage: "doc.on.clipboard"
        ) {
            showingImport = true
        }
        .padding(.top, 20)
    }

    // MARK: Set management

    /// A single set's CSV re-imports cleanly, so this doubles as "send it to a friend"
    /// and "keep a copy I can paste back in".
    private func exportCSV() {
        guard let url = try? Exporter.temporaryFile(named: "\(set.title).csv",
                                                    text: Exporter.csv(for: set)) else {
            Haptics.intenseError()
            return
        }
        Haptics.soft()
        sharingCSV = ShareableFile(url: url)
    }

    private func renameSet() {
        let title = draftTitle.trimmed
        guard !title.isEmpty else { return }
        set.title = title
        set.touch()
        try? context.save()
        Haptics.success()
    }

    private func deleteSet() {
        // Leave the screen *before* deleting. This view binds to `set`, so deleting
        // while it is still on screen means one more render against a torn-down
        // object — navigation title, word list and all.
        Haptics.intenseError()
        dismiss()

        // The words go with the set; so should everything remembered about studying it.
        StudyProgressStore.clearAll(setID: set.id)
        StudyPlaceStore.clearAll(setID: set.id)

        let doomed = set
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            context.delete(doomed)   // words cascade with it
            try? context.save()
        }
    }

    @ViewBuilder
    private func studyView(for mode: StudyMode) -> some View {
        let target = self.target ?? currentTarget
        let cards = cards(for: target)
        let next = continueToNext ? nextTarget(after: target) : nil
        let nextTitle = next.map(label(for:))
        let onNext = next.map { n in { advance(mode, to: n) } }

        switch mode {
        case .memorize:
            MemorizeView(cards: cards, direction: direction,
                         voice: set.language.voiceCode,
                         progressKey: progressKey(.memorize, target),
                         resume: resumeProgress,
                         nextTitle: nextTitle, onNext: onNext)
        case .recall:
            RecallView(
                session: StudySession(cards: cards, mode: .recall, direction: direction,
                                      shuffle: shuffleStudy, resume: resumeProgress),
                progressKey: progressKey(.recall, target),
                nextTitle: nextTitle, onNext: onNext
            )
        case .spell:
            SpellView(
                session: StudySession(cards: cards, mode: .spell, direction: direction,
                                      shuffle: shuffleStudy, resume: resumeProgress),
                progressKey: progressKey(.spell, target),
                nextTitle: nextTitle, onNext: onNext
            )
        }
    }
}

// MARK: - Components

private struct ModeCard: View {
    let mode: StudyMode

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(mode.color.gradient)
                    .frame(width: 52, height: 52)
                Image(systemName: mode.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(mode.korean)  ·  \(mode.english)")
                    .font(.headline)
                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassPanel(tint: mode.color)
    }
}

private struct WordRow: View {
    let word: Vocab
    /// Stars are earned per direction, so the row shows the one being studied.
    let direction: StudyDirection

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term).font(.body.weight(.medium))
                Text(word.meaning).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Haptics.soft()
                Speaker.shared.speak(word.term, language: word.voiceCode)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(word.term) 발음 듣기")
            HStack(spacing: 2) {
                let stars = word.starRating(for: direction)
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < stars ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundStyle(i < stars ? Theme.star : Color.secondary.opacity(0.35))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        // Content, not a control — a quiet fill instead of glass, so a long list
        // doesn't turn into a stack of competing panes.
        .background(RoundedRectangle(cornerRadius: Theme.innerCorner, style: .continuous)
            .fill(Theme.rowFill))
    }
}
