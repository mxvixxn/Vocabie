import SwiftUI
import SwiftData

/// 홈 tab: today's review at a glance.
struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Query private var sets: [VocabSet]

    @State private var showingReview = false

    /// Every card across every active set whose review date has arrived, hardest first.
    /// Archived sets are set aside, so they don't pull cards into today's review.
    private var dueCards: [Vocab] {
        sets.filter { !$0.isArchived }
            .flatMap { $0.dueWords() }
            .sorted { $0.lapses > $1.lapses }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()

                if sets.isEmpty {
                    welcomeState
                } else if dueCards.isEmpty {
                    allCaughtUpState
                } else {
                    VStack(spacing: 0) {
                        Button {
                            Haptics.soft()
                            showingReview = true
                        } label: {
                            ReviewBanner(count: dueCards.count)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Vocabie")
        }
        .tint(Theme.tint)
        .sheet(isPresented: $showingReview) {
            ReviewStartView(dueCards: dueCards)
        }
    }

    private var welcomeState: some View {
        EmptyStateView(
            systemImage: "cloud.sun.fill",
            title: "Vocabie에 오신 걸 환영해요",
            message: "세트 탭에서 첫 단어장을 만들어보세요."
        )
    }

    private var allCaughtUpState: some View {
        EmptyStateView(
            systemImage: "checkmark.circle.fill",
            title: "오늘 복습할 단어가 없어요",
            message: "잘하고 있어요. 내일 다시 확인해요.",
            tint: Theme.correct
        )
    }
}

/// Sits at the top of Home whenever cards have come due.
private struct ReviewBanner: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.tint.gradient)
                    .frame(width: 46, height: 46)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘의 복습")
                    .font(.headline)
                Text("\(count)개 단어가 복습할 때가 됐어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassPanel(tint: Theme.tint)
    }
}
