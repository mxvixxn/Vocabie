import SwiftUI
import SwiftData

/// Today's review: every card across every set whose due date has arrived.
///
/// This is what turns Wordie from "I cleared 60 words tonight" into "I still know them
/// next month" — session repetition only fixes a word for today.
struct ReviewStartView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    let dueCards: [Vocab]

    @State private var direction: StudyDirection = .termToMeaning
    @State private var activeMode: StudyMode?

    /// Cards that keep being forgotten deserve a callout.
    private var leeches: [Vocab] {
        dueCards.filter(\.isLeech)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        summary
                        directionPicker
                        modeButtons
                        if !leeches.isEmpty { leechNote }
                        preview
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("오늘의 복습")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .fullScreenCover(item: $activeMode) { mode in
                switch mode {
                case .recall:
                    RecallView(
                        session: StudySession(cards: dueCards, mode: .recall,
                                              direction: direction, shuffle: true),
                        progressKey: "review|recall"
                    )
                case .spell:
                    SpellView(
                        session: StudySession(cards: dueCards, mode: .spell,
                                              direction: direction, shuffle: true),
                        progressKey: "review|spell"
                    )
                case .memorize:
                    MemorizeView(cards: dueCards, direction: direction)
                }
            }
        }
        .tint(Theme.tint)
    }

    // MARK: Sections

    private var summary: some View {
        VStack(spacing: 6) {
            Text("\(dueCards.count)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.tint)
            Text("복습할 단어")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .glassPanel(corner: 24, tint: Theme.tint)
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

    /// Only retrieval modes are offered — 암기 doesn't grade, so it can't advance a schedule.
    private var modeButtons: some View {
        VStack(spacing: 12) {
            ForEach([StudyMode.recall, .spell]) { mode in
                Button {
                    Haptics.soft()
                    activeMode = mode
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(mode.color.gradient)
                                .frame(width: 46, height: 46)
                            Image(systemName: mode.systemImage)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(mode.korean)(으)로 복습")
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
                .buttonStyle(.plain)
            }
        }
    }

    private var leechNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.star)
            VStack(alignment: .leading, spacing: 2) {
                Text("자꾸 틀리는 단어 \(leeches.count)개")
                    .font(.subheadline.weight(.semibold))
                Text("네 번 이상 잊은 단어예요. 뜻을 다시 다듬어 보세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassPanel(corner: 20)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("복습 목록")
                .font(.headline)
                .padding(.leading, 4)
            ForEach(dueCards.prefix(12)) { card in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.term).font(.body.weight(.medium))
                        Text(card.meaning).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if card.isLeech {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.star)
                    }
                    Text(card.dueDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.05)))
            }
            if dueCards.count > 12 {
                Text("… 외 \(dueCards.count - 12)개 더")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}
