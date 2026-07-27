import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Bulk word entry: paste text or import a file, tune the parse, then add every card at once.
struct ImportWordsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let set: VocabSet

    @State private var rawText = ""
    @State private var delimiter: Delimiter = .auto
    @State private var swapColumns = false
    @State private var showingFileImporter = false
    @State private var importError: String?

    private var rows: [ParsedRow] {
        WordParser.parse(rawText, delimiter: delimiter, swapColumns: swapColumns)
    }

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                optionsSection
                previewSection
            }
            .navigationTitle("단어 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(rows.count)개 추가") { commit() }
                        .disabled(rows.isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            // A real two-way binding — `.constant` leaves SwiftUI unable to dismiss
            // the alert itself, which can strand it on screen.
            .alert("파일을 읽을 수 없어요", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("확인", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    // MARK: Sections

    private var inputSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if rawText.isEmpty {
                    Text("여기에 붙여넣기\n\napple\t사과\nbanana\t바나나\n\n또는  apple, 사과  /  apple - 사과")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $rawText)
                    .frame(minHeight: 160)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
            }
            Button {
                showingFileImporter = true
            } label: {
                Label("파일 불러오기 (CSV·TXT·MD)", systemImage: "doc.badge.plus")
            }
            if !rawText.isEmpty {
                Button(role: .destructive) {
                    rawText = ""
                } label: {
                    Label("입력 지우기", systemImage: "trash")
                }
            }
        } header: {
            Text("붙여넣기 또는 파일")
        } footer: {
            Text("엑셀·구글시트에서 셀을 복사해 붙여넣으면 탭으로 구분돼 자동 인식돼요.")
        }
    }

    private var optionsSection: some View {
        Section("구분 방식") {
            Picker("구분자", selection: $delimiter) {
                ForEach(Delimiter.allCases) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            Toggle("첫 번째 열이 '뜻'이에요 (열 바꾸기)", isOn: $swapColumns)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section {
            if rawText.trimmed.isEmpty {
                Text("입력하면 미리보기가 나타나요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if rows.isEmpty {
                Text("인식된 단어가 없어요. 구분자를 바꿔보세요.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                ForEach(rows.prefix(20)) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.term)
                            .fontWeight(.medium)
                        Spacer(minLength: 12)
                        Text(row.meaning)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.callout)
                }
                if rows.count > 20 {
                    Text("… 외 \(rows.count - 20)개 더")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("미리보기 (\(rows.count)개)")
        }
    }

    // MARK: Actions

    private func commit() {
        let startOrder = (set.words.map(\.order).max() ?? -1) + 1
        for (offset, row) in rows.enumerated() {
            let vocab = Vocab(
                term: row.term,
                meaning: row.meaning,
                note: row.note,
                order: startOrder + offset
            )
            // Register with the context *before* wiring the relationship. Relating a
            // not-yet-inserted object to a persisted one is unreliable in SwiftData —
            // the row can silently fail to attach to the set.
            context.insert(vocab)
            vocab.set = set
        }
        set.touch()
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let text = decodeText(data)
                // Append so a file adds to anything already pasted.
                rawText = rawText.isEmpty ? text : rawText + "\n" + text
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    /// Try UTF-8 first, then fall back to other common encodings.
    private func decodeText(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        for encoding in [String.Encoding.utf16, .isoLatin1, .macOSRoman] {
            if let s = String(data: data, encoding: encoding) { return s }
        }
        return String(decoding: data, as: UTF8.self)
    }
}
