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
    @State private var confirmingDelete = false
    @State private var draftTitle = ""

    // Round (묶음) study — the set is studied 10 cards at a time.
    private let roundSize = 10
    @State private var selectedRound = 0
    // Resume flow for 리콜 / 스펠.
    @State private var showingResumeDialog = false
    @State private var pendingMode: StudyMode?
    @State private var resumeProgress: StudyProgress?

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
                    Button {
                        draftTitle = set.title
                        showingRename = true
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("단어장 삭제", systemImage: "trash")
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
        .alert("이름 변경", isPresented: $showingRename) {
            TextField("단어장 이름", text: $draftTitle)
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
            studyView(for: mode)
        }
        .confirmationDialog(
            "이어서 학습할까요?",
            isPresented: $showingResumeDialog,
            titleVisibility: .visible
        ) {
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
            Text("이 묶음에 저장된 진행이 있어요.")
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
        .glassPanel(corner: 24)
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

    /// Cards split into rounds of `roundSize`. Sets of 10 or fewer are one round.
    private var rounds: [[Vocab]] {
        let words = set.orderedWords
        guard words.count > roundSize else { return [words] }
        return stride(from: 0, to: words.count, by: roundSize).map {
            Array(words[$0 ..< min($0 + roundSize, words.count)])
        }
    }

    private var hasRounds: Bool { self.set.wordCount > roundSize }
    private var currentRound: Int { rounds.indices.contains(selectedRound) ? selectedRound : 0 }
    private var roundCards: [Vocab] { rounds.isEmpty ? [] : rounds[currentRound] }

    private func roundRangeLabel(_ i: Int) -> String {
        guard rounds.indices.contains(i) else { return "" }
        return "\(i * roundSize + 1)–\(i * roundSize + rounds[i].count)"
    }

    /// A round is "done" once every card in it is fully mastered (3 stars).
    private func roundMastered(_ i: Int) -> Bool {
        guard rounds.indices.contains(i) else { return false }
        return rounds[i].allSatisfy { $0.starRating >= 3 }
    }

    private var firstUnfinishedRound: Int {
        rounds.firstIndex { round in !round.allSatisfy { $0.starRating >= 3 } } ?? 0
    }

    /// Land on the first unfinished round, unless the learner is mid-way through one.
    private func syncSelectedRound() {
        if !rounds.indices.contains(selectedRound) || roundMastered(selectedRound) {
            selectedRound = firstUnfinishedRound
        }
    }

    private func progressKey(_ mode: StudyMode) -> String {
        "\(mode.rawValue)|\(set.id.uuidString)|\(currentRound)"
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
                    selectedRound = i
                } label: {
                    if roundMastered(i) {
                        Label("묶음 \(i + 1) (\(roundRangeLabel(i)))", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("묶음 \(i + 1) (\(roundRangeLabel(i)))")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill").font(.caption)
                Text("묶음 \(currentRound + 1) · \(roundRangeLabel(currentRound))")
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.tint)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Theme.tint.opacity(0.12), in: Capsule())
        }
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
                shuffleStudy ? AnyShapeStyle(Theme.tint) : AnyShapeStyle(Color.primary.opacity(0.06)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    /// Launch a mode. 리콜 / 스펠 first offer to resume any saved progress.
    private func launch(_ mode: StudyMode) {
        resumeProgress = nil
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
            Text("단어 목록")
                .font(.headline)
                .padding(.leading, 4)
            ForEach(set.orderedWords) { word in
                Button {
                    editingWord = word
                } label: {
                    WordRow(word: word)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $editingWord) { word in
            EditWordView(set: set, word: word)
        }
    }

    @State private var editingWord: Vocab?

    private var emptyWords: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("단어가 아직 없어요")
                .font(.headline)
            Text("우측 상단 ＋ 에서 붙여넣기나 파일로\n단어를 한 번에 추가해 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingImport = true
            } label: {
                Label("대량 추가", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(Theme.tint, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .glassPanel(corner: 24)
        .padding(.top, 30)
    }

    // MARK: Set management

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
        let cards = roundCards
        switch mode {
        case .memorize:
            MemorizeView(cards: cards, direction: direction)
        case .recall:
            RecallView(
                session: StudySession(cards: cards, mode: .recall, direction: direction,
                                      shuffle: shuffleStudy, resume: resumeProgress),
                progressKey: progressKey(.recall)
            )
        case .spell:
            SpellView(
                session: StudySession(cards: cards, mode: .spell, direction: direction,
                                      shuffle: shuffleStudy, resume: resumeProgress),
                progressKey: progressKey(.spell)
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
        .glassPanel(corner: 24, tint: mode.color)
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(0.05)))
    }
}
