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
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label("알림", systemImage: "bell")
                        }
                        NavigationLink {
                            ArchiveView()
                        } label: {
                            Label("보관함", systemImage: "archivebox")
                        }
                    }
                    .listRowBackground(Theme.rowFill)

                    Section {
                        placeholderRow("paintbrush", "테마")
                        placeholderRow("square.and.arrow.up", "단어장 내보내기")
                    }
                    .listRowBackground(Theme.rowFill)
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
