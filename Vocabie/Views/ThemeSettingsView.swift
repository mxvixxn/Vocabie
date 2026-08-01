import SwiftUI

/// 설정 › 테마 — how the app looks: light or dark, and which accent carries it.
///
/// Both settings apply the moment they are picked; this screen sits under the same
/// theme it is editing, so the preview *is* the app.
struct ThemeSettingsView: View {
    @Environment(\.colorScheme) private var scheme

    @AppStorage(Theme.appearanceKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(Theme.accentKey) private var accentRaw = AccentTheme.periwinkle.rawValue

    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }
    private var accent: AccentTheme { AccentTheme(rawValue: accentRaw) ?? .periwinkle }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            List {
                Section {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button { select(mode) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: mode.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(Theme.tint)
                                    .frame(width: 28)
                                Text(mode.korean).foregroundStyle(.primary)
                                Spacer()
                                if mode == appearance {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("화면 모드")
                }
                .listRowBackground(Theme.rowFill)

                Section {
                    ForEach(AccentTheme.allCases) { option in
                        Button { select(option) } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(option.color.gradient)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                                    }
                                Text(option.korean).foregroundStyle(.primary)
                                Spacer()
                                if option == accent {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(option.color)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("강조 색상")
                } footer: {
                    Text("암기·리콜·스펠 카드 색은 학습 중에 서로 구분되어야 해서 그대로 둡니다.")
                }
                .listRowBackground(Theme.rowFill)

                Section {
                    preview
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    Text("미리보기")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("테마")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("41-45")
                    .font(.headline)
                Spacer()
                Text("46단어")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: 0.33).tint(Theme.tint)
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.star)
                Text("15").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text("복습 4")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.tint.opacity(0.14)))
                    .padding(.leading, 4)
                Spacer()
                Text("33% 완료").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(Theme.contentPad)
        .glassPanel()
    }

    private func select(_ mode: AppearanceMode) {
        Haptics.selection()
        withAnimation { appearanceRaw = mode.rawValue }
    }

    private func select(_ option: AccentTheme) {
        Haptics.selection()
        withAnimation { accentRaw = option.rawValue }
    }
}
