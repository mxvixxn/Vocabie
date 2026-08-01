import SwiftUI

/// 설정 tab — study behaviour, then the screens that manage the library and its look.
struct SettingsView: View {
    /// The accent's raw value, passed down purely so a theme change re-renders this
    /// tab. See the note at the bottom of `MainTabView`.
    var theme: String = ""

    @Environment(\.colorScheme) private var scheme

    /// Offer the next 묶음 / 세트 at the end of a session instead of just stopping.
    @AppStorage("continueToNext") private var continueToNext = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()
                List {
                    Section {
                        Toggle(isOn: $continueToNext) {
                            Label("다음 묶음·세트 이어서 하기", systemImage: "forward.end")
                        }
                    } header: {
                        Text("학습")
                    } footer: {
                        Text("학습을 끝내면 다음 묶음이나 같은 단어장의 다음 세트로 이어갈지 물어봐요.")
                    }
                    .listRowBackground(Theme.rowFill)

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
                        NavigationLink {
                            ExportView()
                        } label: {
                            Label("내보내기 · 복원", systemImage: "square.and.arrow.up")
                        }
                    }
                    .listRowBackground(Theme.rowFill)

                    Section {
                        NavigationLink {
                            ThemeSettingsView()
                        } label: {
                            Label("테마", systemImage: "paintbrush")
                        }
                    }
                    .listRowBackground(Theme.rowFill)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("설정")
        }
        .tint(Theme.tint)
    }

}
