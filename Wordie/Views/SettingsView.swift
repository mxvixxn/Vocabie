import SwiftUI

/// 설정 tab. Placeholder — the category lives here so it's not lost, screens land later.
struct SettingsView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()
                List {
                    Section {
                        placeholderRow("bell", "알림")
                        placeholderRow("paintbrush", "테마")
                        placeholderRow("square.and.arrow.up", "단어장 내보내기")
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("설정")
        }
        .tint(Theme.tint)
    }

    private func placeholderRow(_ systemImage: String, _ title: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text("준비 중")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
    }
}
