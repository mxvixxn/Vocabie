import SwiftUI
import SwiftData

/// The hub for one set: pick a study mode or manage its words.
struct SetDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Bindable var set: VocabSet

    @AppStorage("autoSpeak") private var autoSpeak = true

    @State private var direction: StudyDirection = .termToMeaning
    @State private var showingImport = false
    @State private var showingAddOne = false
    @State private var activeMode: StudyMode?

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
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            ImportWordsView(set: set)
        }
        .sheet(isPresented: $showingAddOne) {
            EditWordView(set: set, word: nil)
        }
        .fullScreenCover(item: $activeMode) { mode in
            studyView(for: mode)
        }
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
                    activeMode = mode
                } label: {
                    ModeCard(mode: mode)
                }
                .buttonStyle(.plain)
            }
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

    @ViewBuilder
    private func studyView(for mode: StudyMode) -> some View {
        switch mode {
        case .memorize:
            MemorizeView(cards: set.orderedWords, direction: direction)
        case .recall:
            RecallView(session: StudySession(cards: set.orderedWords, mode: .recall, direction: direction))
        case .spell:
            SpellView(session: StudySession(cards: set.orderedWords, mode: .spell, direction: direction))
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
