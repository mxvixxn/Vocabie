import SwiftUI

/// One-time overlay teaching the 단어장 row gestures — 왼쪽 = 이름 변경, 오른쪽 = 삭제.
/// Shown once on first launch, dismissed and remembered via `wordie.hasSeenSwipeTutorial`.
struct SwipeTutorialView: View {
    let onDismiss: () -> Void

    @State private var phase: Phase = .center
    @State private var loopTask: Task<Void, Never>?

    private enum Phase { case center, rename, delete }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 8) {
                    Text("단어장 정리하기")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("단어장을 좌우로 밀어보세요")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                demoRow
                    .padding(.horizontal, 36)

                VStack(alignment: .leading, spacing: 14) {
                    hintRow(systemImage: "pencil", text: "이름 변경", active: phase == .rename)
                    hintRow(systemImage: "trash", text: "삭제", active: phase == .delete)
                }

                Spacer()

                Button {
                    Haptics.soft()
                    loopTask?.cancel()
                    onDismiss()
                } label: {
                    Text("확인했어요")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.tint, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 44)
            }
        }
        .onAppear { startLoop() }
        .onDisappear { loopTask?.cancel() }
    }

    private func hintRow(systemImage: String, text: String, active: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 22)
            Text(text)
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(active ? .white : .white.opacity(0.5))
        .animation(.easeInOut(duration: 0.3), value: active)
    }

    private var demoRow: some View {
        ZStack {
            HStack {
                actionChip(systemImage: "pencil", color: .blue)
                    .opacity(phase == .rename ? 1 : 0)
                Spacer()
                actionChip(systemImage: "trash", color: .red)
                    .opacity(phase == .delete ? 1 : 0)
            }

            HStack {
                Text("예문 단어장")
                    .font(.headline)
                Spacer()
                Text("12단어")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .offset(x: rowOffset)
        }
        .frame(height: 64)
    }

    private func actionChip(systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The row slides toward whichever edge is being demoed, revealing that action behind it.
    private var rowOffset: CGFloat {
        switch phase {
        case .center: return 0
        case .rename: return 68
        case .delete: return -68
        }
    }

    private func startLoop() {
        loopTask = Task {
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.45)) { phase = .rename }
                try? await Task.sleep(nanoseconds: 950_000_000)
                withAnimation(.easeInOut(duration: 0.35)) { phase = .center }
                try? await Task.sleep(nanoseconds: 450_000_000)
                withAnimation(.easeInOut(duration: 0.45)) { phase = .delete }
                try? await Task.sleep(nanoseconds: 950_000_000)
                withAnimation(.easeInOut(duration: 0.35)) { phase = .center }
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
        }
    }
}
