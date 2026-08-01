import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 설정 → 내보내기, and the way a backup comes back in.
///
/// Vocabie stores everything on the device with no account behind it, so this screen is
/// the only thing standing between a learner and losing months of work to a lost phone.
struct ExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query private var sets: [VocabSet]

    @State private var sharing: ShareableFile?
    @State private var showingRestorePicker = false
    @State private var notice: Notice?

    private var wordCount: Int { sets.reduce(0) { $0 + $1.wordCount } }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if sets.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "내보낼 세트가 없어요",
                    message: "세트를 만들면 여기에서 백업할 수 있어요."
                )
            } else {
                list
            }
        }
        .navigationTitle("내보내기 · 복원")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharing) { file in
            ShareSheet(items: [file.url])
        }
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [.json]
        ) { result in
            restore(from: result)
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title),
                  message: Text(notice.body),
                  dismissButton: .default(Text("확인")))
        }
    }

    private var list: some View {
        List {
            Section {
                // .plain, or the list tints the whole label — caption included — blue.
                Button { shareBackup() } label: {
                    row("전체 백업", "arrow.down.doc.fill",
                        "세트 \(sets.count)개 · \(wordCount)단어")
                }
                .buttonStyle(.plain)
                Button { shareCSV() } label: {
                    row("전체 단어 (CSV)", "tablecells",
                        "엑셀·구글시트에서 열 수 있어요")
                }
                .buttonStyle(.plain)
            } header: {
                Text("내보내기")
            } footer: {
                Text("백업(JSON)은 별점·복습 일정과 어느 단어장에 있었는지까지 담아요. CSV는 단어·뜻·메모만 담습니다.\n세트 하나만 보내려면 그 세트의 ⋯ 메뉴를 쓰세요.")
            }
            .listRowBackground(Theme.rowFill)

            Section {
                Button { showingRestorePicker = true } label: {
                    row("백업에서 복원", "arrow.up.doc.fill",
                        "Vocabie 백업 파일(.json) 선택")
                }
                .buttonStyle(.plain)
            } footer: {
                Text("백업 속 세트를 새 세트로 추가하고, 담겨 있던 단어장도 새로 만들어요. 지금 있는 항목은 건드리지 않습니다.")
            }
            .listRowBackground(Theme.rowFill)
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ title: String, _ systemImage: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: Actions

    /// The order the library shows: shelf by shelf as arranged, unfiled sets last.
    /// An export that reads like the app is one a learner can check at a glance — and
    /// restoring it lays the sets back down in the same order.
    private var ordered: [VocabSet] {
        sets.sorted { a, b in
            if a.notebook?.id != b.notebook?.id {
                guard let left = a.notebook else { return false }
                guard let right = b.notebook else { return true }
                return Notebook.inListOrder(left, right)
            }
            return VocabSet.inListOrder(a, b)
        }
    }

    private func shareBackup() {
        do {
            let data = try Exporter.backupData(for: ordered)
            let url = try Exporter.temporaryFile(
                named: "Vocabie-백업-\(Exporter.dateStamp).json", data: data)
            Haptics.soft()
            sharing = ShareableFile(url: url)
        } catch {
            fail("백업을 만들지 못했어요", "잠시 후 다시 시도해 주세요.")
        }
    }

    private func shareCSV() {
        do {
            let url = try Exporter.temporaryFile(
                named: "Vocabie-\(Exporter.dateStamp).csv",
                text: Exporter.csv(forAll: ordered))
            Haptics.soft()
            sharing = ShareableFile(url: url)
        } catch {
            fail("CSV를 만들지 못했어요", "잠시 후 다시 시도해 주세요.")
        }
    }

    private func restore(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // A file handed over by the document picker lives outside the sandbox
            // until we ask for it.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let backup = try Exporter.decodeBackup(try Data(contentsOf: url))
            let count = try Exporter.restore(backup, into: context)
            Haptics.success()
            notice = Notice(title: "복원했어요",
                            body: "세트 \(count)개를 추가했어요.")
        } catch is CocoaError {
            fail("파일을 읽지 못했어요", "파일이 옮겨졌거나 접근할 수 없어요.")
        } catch {
            fail("복원하지 못했어요", "Vocabie 백업 파일(.json)이 맞는지 확인해 주세요.")
        }
    }

    private func fail(_ title: String, _ body: String) {
        Haptics.intenseError()
        notice = Notice(title: title, body: body)
    }

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }
}
