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
    // Resume flow for 리콜 / 스펠.
    @State private var showingResumeDialog = false
    @State private var pendingMode: StudyMode?
    @State private var resumeProgress: StudyProgress?

    /// What the open study cover is working on. Normally this set's selected 묶음, but
    /// "이어서" moves it on — to the next 묶음, or to the next 세트 on the same 단어장 —
    /// without ever leaving the cover.
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
                    Button { showingImport = true } label: {
                        Label("대량 추가 (붙여넣기·파일)", systemImage: "doc.badge.plus")
                    }
                    Button { showingAddOne = true } label: {
                        Label("단어 하나 추가", systemImage: "plus")
                    }
                    Divider()
                    Toggle(isOn: $autoSpeak) {
                        Label("카드 넘길 때 발음 듣기", systemImage: "speaker.wave.2")
                    }
                    Divider()
                    Button { showingWordOrder = true } label: {
                        Label("단어 순서 바꾸기", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(set.wordCount < 2)
                    Divider()
                    Button { exportCSV() } label: {
                        Label("CSV로 내보내기", systemImage: "square.and.arrow.up")
                    }
                    .disabled(set.words.isEmpty)
                    Divider()
                    Button {
                        draftTitle = set.title
                        showingRename = true
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    Button { showingMove = true } label: {
                        Label(set.notebook == nil ? "단어장에 넣기" : "단어장 이동",
                              systemImage: "folder")
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("세트 삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.title3)
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
            Button("이어서 (\(resumeProgress?.clearedIDs.count ?? 0)/\(resumeProgress?.total ?? 0))") {
                activeMode = pendingMode
            }
            Button("처음부터", role: .destructive) {
                if let mode = pendingMode { StudyProgressStore.clear(progressKey(mode)) }
                resumeProgress = nil
                activeMode = pendingMode
            }
            Button("취소", role: .cancel) { pendingMode = nil; resumeProgress = nil }
        } message: {
            // Name the mode — the learner needs to know *this* is the 스펠 they tapped.
            Text("‘\(pendingMode?.korean ?? "")’ \(scopeLabel)에 저장된 진행이 있어요.")
        }
        .onAppear(perform: syncSelectedRound)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text("\(set.wordCount)단어 · \(Int(set.masteryProgress * 100))% 완료")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ProgressView(value: set.masteryProgress)
                .tint(Theme.tint)
        }
        .padding(16)
        .glassPanel()
        .padding(.top, 8)
    }

    private var directionPicker: some View {
        Picker("방향", selection: $direction) {
            ForEach(StudyDirection.allCases) { d in
                Text(d.label).tag(d)
            }
        }
        .pickerStyle(.segmented)
    }

    private var modeCards: some View {
        VStack(spacing: 12) {
            ForEach(StudyMode.allCases) { mode in
                Button {
                    Haptics.soft()
                    launch(mode)
                } label: {
                    ModeCard(mode: mode)
                }
                .buttonStyle(.plain)
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
        return rounds[i].allSatisfy { $0.starRating >= 3 }
    }

    private var firstUnfinishedRound: Int {
        rounds.firstIndex { round in !round.allSatisfy { $0.starRating >= 3 } } ?? 0
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

    /// What follows this chunk: the next 묶음 of the same set, or failing that the next
    /// set on the same 단어장, in the order the list shows them. `nil` at the end of the
    /// shelf, and for a set that isn't on one — there is nothing to name in that case.
    private func nextTarget(after target: StudyTarget) -> StudyTarget? {
        // Studying 전체 already covered the set, so the only thing left is the next one.
        if target.round != Self.wholeSet,
           rounds(of: target.set).indices.contains(target.round + 1) {
            return StudyTarget(set: target.set, round: target.round + 1)
        }
        guard let notebook = target.set.notebook else { return nil }
        let siblings = notebook.orderedSets.filter { $0.isActive && !$0.words.isEmpty }
        guard let i = siblings.firstIndex(where: { $0.id == target.set.id }),
              siblings.indices.contains(i + 1) else { return nil }
        return StudyTarget(set: siblings[i + 1], round: 0)
    }

    private func label(for target: StudyTarget) -> String {
        let chunks = rounds(of: target.set)
        let hasMany = chunks.count > 1
        if target.set.id == set.id {
            guard target.round != Self.wholeSet else { return "\(target.set.title) 전체" }
            return hasMany ? "묶음 \(target.round + 1) · \(rangeLabel(chunks, target.round))"
                           : target.set.title
        }
        return hasMany ? "\(target.set.title) 묶음 1" : target.set.title
    }

    /// Hand the open cover over to the next chunk. Any progress already saved for it is
    /// picked up rather than overwritten — "이어서" should never quietly discard a round
    /// the learner was half way through.
    private func advance(_ mode: StudyMode, to next: StudyTarget) {
        Haptics.soft()
        if mode != .memorize,
           let saved = StudyProgressStore.load(progressKey(mode, next)),
           saved.total > 0, saved.clearedIDs.count < saved.total {
            resumeProgress = saved
        } else {
            resumeProgress = nil
        }
        if next.set.id == set.id { selectedRound = next.round }
        target = next
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

    /// Launch a mode. 리콜 / 스펠 first offer to resume any saved progress.
    private func launch(_ mode: StudyMode) {
        resumeProgress = nil
        target = currentTarget
        if mode != .memorize,
           let saved = StudyProgressStore.load(progressKey(mode)),
           saved.total > 0, saved.clearedIDs.count < saved.total {
            pendingMode = mode
            resumeProgress = saved
            showingResumeDialog = true
        } else {
            activeMode = mode
        }
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
                        WordRow(word: word)
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
            message: "우측 상단 ＋ 에서 붙여넣기나 파일로\n단어를 한 번에 추가해 보세요.",
            actionTitle: "대량 추가",
            actionImage: "doc.badge.plus"
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term).font(.body.weight(.medium))
                Text(word.meaning).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Haptics.soft()
                Speaker.shared.speak(word.term)
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
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < word.starRating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundStyle(i < word.starRating ? Theme.star : Color.secondary.opacity(0.35))
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
