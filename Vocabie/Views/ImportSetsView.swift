import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Paste a whole 회차 at once: the headings in the text become 세트, the words under
/// each become its cards, and everything lands on one 단어장.
///
/// This is the counterpart to `ImportWordsView`, which fills a single set. The parser
/// already has to recognise `43~45번 (13)` to keep it out of the word list — here that
/// same recognition is used as a boundary instead of as noise, which removes the step
/// the learner was doing by hand: make a set, paste, go back, make the next set.
struct ImportSetsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The shelf to fill. `nil` means one is created from `notebookTitle`.
    var notebook: Notebook?

    @State private var rawText = ""
    @State private var notebookTitle = ""
    @State private var delimiter: Delimiter = .auto
    @State private var swapColumns = false
    @State private var showingFileImporter = false
    @State private var importError: String?

    /// Titles the learner has overridden, and sections they've switched off — both
    /// keyed by position, and both cleared whenever the text changes underneath them.
    @State private var titleEdits: [Int: String] = [:]
    @State private var excluded: Set<Int> = []

    private var sections: [ParsedSection] {
        WordParser.sections(rawText, delimiter: delimiter, swapColumns: swapColumns)
    }

    private var includedIndices: [Int] {
        sections.indices.filter { !excluded.contains($0) }
    }

    private var wordCount: Int {
        includedIndices.reduce(0) { $0 + sections[$1].rows.count }
    }

    private var canCreate: Bool {
        guard !includedIndices.isEmpty else { return false }
        return notebook != nil || !notebookTitle.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if notebook == nil { notebookSection }
                inputSection
                optionsSection
                previewSection
            }
            .navigationTitle(notebook == nil ? "붙여넣기로 단어장 만들기" : "세트 여러 개 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("세트 \(includedIndices.count)개 만들기") { create() }
                        .disabled(!canCreate)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: rawText) { _, _ in
                // Positions shift when the text changes, so per-position edits would
                // land on the wrong section. Start clean rather than quietly wrong.
                titleEdits = [:]
                excluded = []
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
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

    private var notebookSection: some View {
        Section("단어장") {
            TextField("이름 (예: 2026 6월 모의고사)", text: $notebookTitle)
        }
    }

    private var inputSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if rawText.isEmpty {
                    Text("회차 전체를 그대로 붙여넣기\n\n18~23번 (24)\n1. struggle — 노력\n…\n\n24-30번 (18)\n1. inhibit — 방해하다")
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
            Text("‘43~45번’, ‘3강’처럼 번호나 강으로 된 줄을 만나면 거기서 세트를 나눠요. 그런 줄이 없으면 세트 하나로 들어갑니다.")
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
                Text("붙여넣으면 나눠질 세트가 여기에 보여요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if sections.isEmpty {
                Text("인식된 단어가 없어요. 구분자를 바꿔보세요.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                ForEach(sections.indices, id: \.self) { index in
                    sectionRow(index)
                }
            }
        } header: {
            Text(sections.isEmpty ? "나눠질 세트" : "나눠질 세트 (\(includedIndices.count)개 · \(wordCount)단어)")
        } footer: {
            if sections.count > 1 {
                Text("이름은 눌러서 고칠 수 있어요. 끄면 그 세트는 만들지 않아요.")
            }
        }
    }

    private func sectionRow(_ index: Int) -> some View {
        let section = sections[index]
        let isOn = !excluded.contains(index)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("세트 이름", text: Binding(
                    get: { title(at: index) },
                    set: { titleEdits[index] = $0 }
                ))
                .font(.body.weight(.medium))
                .disabled(!isOn)
                Spacer(minLength: 12)
                Text("\(section.rows.count)단어")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { on in
                        Haptics.selection()
                        if on { excluded.remove(index) } else { excluded.insert(index) }
                    }
                ))
                .labelsHidden()
            }
            Text(preview(of: section))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .opacity(isOn ? 1 : 0.45)
    }

    /// The first few terms, so a section is recognisable without expanding it.
    private func preview(of section: ParsedSection) -> String {
        let terms = section.rows.prefix(4).map(\.term)
        let more = section.rows.count - terms.count
        return terms.joined(separator: " · ") + (more > 0 ? " …" : "")
    }

    /// A section's set title: the learner's edit, the heading it was pasted with, or a
    /// position-based fallback for words that arrived before any heading.
    private func title(at index: Int) -> String {
        if let edited = titleEdits[index] { return edited }
        let parsed = sections[index].title
        return parsed.isEmpty ? "세트 \(index + 1)" : parsed
    }

    // MARK: Actions

    private func create() {
        let shelf: Notebook
        if let notebook {
            shelf = notebook
        } else {
            let made = Notebook(title: notebookTitle.trimmed)
            context.insert(made)
            shelf = made
        }

        // Land after whatever is already on the shelf, in the order pasted.
        let base = (shelf.sets.map(\.order).max() ?? -1) + 1
        let snapshot = sections

        for (offset, index) in includedIndices.enumerated() {
            let set = VocabSet(title: title(at: index))
            set.order = base + offset
            context.insert(set)
            set.notebook = shelf

            for (position, row) in snapshot[index].rows.enumerated() {
                let vocab = Vocab(term: row.term, meaning: row.meaning,
                                  note: row.note, order: position)
                // Insert before relating: SwiftData can silently drop a relationship
                // wired from an object the context hasn't seen yet.
                context.insert(vocab)
                vocab.set = set
            }
        }

        shelf.touch()
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
