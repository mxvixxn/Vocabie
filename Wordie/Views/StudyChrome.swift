import SwiftUI

/// Top bar shared by every study screen: a close button, a title, and a progress bar.
struct StudyTopBar: View {
    let title: String
    let progress: Double
    let accent: Color
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    Haptics.soft()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                Spacer()
                Text(title)
                    .font(.headline)
                Spacer()
                // Balance the layout with an invisible mirror of the close button.
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .opacity(0)
            }
            ProgressView(value: progress)
                .tint(accent)
                .animation(.easeInOut, value: progress)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

/// Shown when a session clears every card.
struct StudyCompleteView: View {
    let mode: StudyMode
    let total: Int
    let onRestart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(mode.color.gradient)
                .symbolEffect(.bounce, options: .nonRepeating)
            VStack(spacing: 6) {
                Text("\(mode.korean) 학습 완료!")
                    .font(.title2.weight(.bold))
                Text("\(total)개 단어를 모두 맞혔어요 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button(action: onRestart) {
                    Label("한 번 더", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(mode.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                Button(action: onClose) {
                    Text("끝내기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
