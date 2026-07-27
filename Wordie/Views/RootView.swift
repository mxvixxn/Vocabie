import SwiftUI
import SwiftData

/// Home screen: the list of study sets (단어장).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \VocabSet.updatedAt, order: .reverse) private var sets: [VocabSet]

    @State private var showingNewSet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()

                if sets.isEmpty {
                    emptyState
                } else {
                    setList
                }
            }
            .navigationTitle("Wordie")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.soft()
                        showingNewSet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.tint)
                    }
                }
            }
            .sheet(isPresented: $showingNewSet) {
                NewSetView()
            }
        }
        .tint(Theme.tint)
    }

    private var setList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(sets) { set in
                    NavigationLink(value: set) {
                        SetRow(set: set)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationDestination(for: VocabSet.self) { set in
            SetDetailView(set: set)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.tint.gradient)
            Text("아직 단어장이 없어요")
                .font(.title3.weight(.semibold))
            Text("＋ 버튼을 눌러 첫 단어장을 만들고\nCSV·엑셀·텍스트를 붙여넣어 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Haptics.soft()
                showingNewSet = true
            } label: {
                Label("단어장 만들기", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.tint, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .padding(40)
    }
}

private struct SetRow: View {
    let set: VocabSet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.title.isEmpty ? "제목 없는 단어장" : set.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(set.wordCount)단어")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if !set.detail.isEmpty {
                Text(set.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ProgressView(value: set.masteryProgress)
                .tint(Theme.tint)
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.star)
                Text("\(set.totalStars)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(set.masteryProgress * 100))% 완료")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface()
    }
}
