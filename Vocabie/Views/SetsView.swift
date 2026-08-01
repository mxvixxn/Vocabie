import SwiftUI
import SwiftData

/// 단어장 tab — the top of the library: 단어장 first, then any set that isn't on a shelf.
///
/// Two levels, no more. A 단어장 holds 세트, a 세트 holds 단어, and a set can skip the
/// shelf entirely; nesting deeper would buy nothing that a good title doesn't.
struct SetsView: View {
    /// The accent's raw value, passed down purely so a theme change re-renders this
    /// tab. See the note at the bottom of `MainTabView`.
    var theme: String = ""

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(filter: #Predicate<Notebook> { !$0.isArchived },
           sort: [SortDescriptor(\Notebook.order),
                  SortDescriptor(\Notebook.updatedAt, order: .reverse)])
    private var notebooks: [Notebook]

    @Query(filter: #Predicate<VocabSet> { !$0.isArchived },
           sort: [SortDescriptor(\VocabSet.order),
                  SortDescriptor(\VocabSet.updatedAt, order: .reverse)])
    private var sets: [VocabSet]

    @State private var showingNewSet = false
    @State private var showingNewNotebook = false
    @State private var showingImportSets = false
    @State private var actions = SetActions()
    /// Drag-to-reorder is behind a mode: the rows already carry swipe actions, and a
    /// list that reorders on every long press fights them.
    @State private var editMode: EditMode = .inactive

    /// Notebook awaiting delete confirmation — it takes its sets and their words.
    @State private var pendingDeletion: Notebook?
    @State private var renameTarget: Notebook?
    @State private var draftTitle = ""

    @AppStorage("vocabie.hasSeenSwipeTutorial") private var hasSeenSwipeTutorial = false

    /// Sets that aren't on any shelf. They stay on the front page rather than hiding
    /// behind a 미분류 folder — making a set without first making a 단어장 has to
    /// remain a one-tap path, and a set you can't see is a set you won't study.
    private var looseSets: [VocabSet] {
        sets.filter { $0.notebook == nil }
    }

    private var isEmpty: Bool { notebooks.isEmpty && looseSets.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()

                if isEmpty {
                    emptyState
                } else {
                    libraryList
                }
            }
            .navigationTitle("단어장")
            .environment(\.editMode, $editMode)
            .toolbar {
                if editMode == .active {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") {
                            Haptics.soft()
                            withAnimation { editMode = .inactive }
                        }
                        .font(.body.weight(.semibold))
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                Haptics.soft()
                                showingNewNotebook = true
                            } label: {
                                Label("새 단어장", systemImage: "books.vertical")
                            }
                            Button {
                                Haptics.soft()
                                showingNewSet = true
                            } label: {
                                Label("새 세트", systemImage: "square.stack")
                            }
                            Button {
                                Haptics.soft()
                                showingImportSets = true
                            } label: {
                                Label("붙여넣기로 단어장 만들기", systemImage: "doc.on.clipboard")
                            }
                            if notebooks.count + looseSets.count > 1 {
                                Divider()
                                Button {
                                    Haptics.soft()
                                    withAnimation { editMode = .active }
                                } label: {
                                    Label("순서 바꾸기", systemImage: "arrow.up.arrow.down")
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.tint)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewSet) {
                NewSetView()
            }
            .sheet(isPresented: $showingNewNotebook) {
                NewNotebookView()
            }
            .sheet(isPresented: $showingImportSets) {
                ImportSetsView()
            }
            .setActionDialogs(actions)
            .confirmationDialog(
                "‘\(pendingDeletion?.title ?? "")’을(를) 삭제할까요?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { deletePendingNotebook() }
                Button("취소", role: .cancel) { pendingDeletion = nil }
            } message: {
                if let notebook = pendingDeletion {
                    Text("세트 \(notebook.setCount)개와 단어 \(notebook.wordCount)개가 함께 사라져요. 되돌릴 수 없어요.")
                }
            }
            .alert("이름 변경", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("단어장 이름", text: $draftTitle)
                Button("취소", role: .cancel) { renameTarget = nil }
                Button("저장") { if let notebook = renameTarget { rename(notebook) } }
            }
        }
        .tint(Theme.tint)
        .overlay {
            if !hasSeenSwipeTutorial {
                SwipeTutorialView {
                    withAnimation(.easeInOut(duration: 0.25)) { hasSeenSwipeTutorial = true }
                }
                .transition(.opacity)
            }
        }
    }

    private var libraryList: some View {
        List {
            if !notebooks.isEmpty {
                Section {
                    ForEach(notebooks) { notebook in
                        NavigationLink(value: notebook) {
                            NotebookRow(notebook: notebook)
                        }
                        .navigationLinkIndicatorVisibility(.hidden)
                        .plainRow()
                        .swipeActions(edge: .leading) {
                            Button {
                                Haptics.selection()
                                draftTitle = notebook.title
                                renameTarget = notebook
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Haptics.selection()
                                pendingDeletion = notebook
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                            .tint(.red)
                            Button {
                                archive(notebook)
                            } label: {
                                Label("보관", systemImage: "archivebox")
                            }
                            .tint(Theme.tint)
                        }
                    }
                    .onMove(perform: moveNotebooks)
                } header: {
                    sectionHeader("단어장")
                }
            }

            if !looseSets.isEmpty {
                Section {
                    ForEach(looseSets) { set in
                        SetListRow(set: set, actions: actions)
                    }
                    .onMove(perform: moveLooseSets)
                } header: {
                    sectionHeader(notebooks.isEmpty ? "세트" : "단어장에 없는 세트")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: Notebook.self) { notebook in
            NotebookDetailView(notebook: notebook)
        }
        .navigationDestination(for: VocabSet.self) { set in
            SetDetailView(set: set)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 2, trailing: 16))
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "cloud.sun.fill",
            title: "아직 단어장이 없어요",
            message: "＋ 버튼으로 단어장을 만들어 회차별 세트를 모아두거나,\n세트를 바로 만들어 CSV·엑셀·텍스트를 붙여넣어 보세요.",
            actionTitle: "단어장 만들기",
            actionImage: "plus"
        ) {
            Haptics.soft()
            showingNewNotebook = true
        }
    }

    // MARK: Reordering

    private func moveNotebooks(from source: IndexSet, to destination: Int) {
        Reorder.apply(notebooks, from: source, to: destination) { $0.order = $1 }
        try? context.save()
    }

    /// Unfiled sets are numbered among themselves. A set that later moves onto a shelf
    /// keeps its number, which is harmless — the shelf renumbers on its first drag.
    private func moveLooseSets(from source: IndexSet, to destination: Int) {
        Reorder.apply(looseSets, from: source, to: destination) { $0.order = $1 }
        try? context.save()
    }

    // MARK: Notebook actions

    private func deletePendingNotebook() {
        guard let notebook = pendingDeletion else { return }
        // Clear the reference first so the dialog stops reading a deleted object.
        pendingDeletion = nil
        // Sets cascade from the notebook, and words cascade from the sets.
        withAnimation { context.delete(notebook) }
        try? context.save()
        Haptics.intenseError()
    }

    private func archive(_ notebook: Notebook) {
        Haptics.selection()
        withAnimation {
            notebook.isArchived = true
            notebook.touch()
        }
        try? context.save()
    }

    private func rename(_ notebook: Notebook) {
        let title = draftTitle.trimmed
        renameTarget = nil
        guard !title.isEmpty else { return }
        notebook.title = title
        notebook.touch()
        try? context.save()
        Haptics.success()
    }
}

// MARK: - Row

struct NotebookRow: View {
    let notebook: Notebook

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.tint)
                Text(notebook.title.isEmpty ? "제목 없는 단어장" : notebook.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("세트 \(notebook.setCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if !notebook.detail.isEmpty {
                Text(notebook.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ProgressView(value: notebook.masteryProgress)
                .tint(Theme.tint)
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.star)
                Text("\(notebook.totalStars)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                let due = notebook.dueCount()
                if due > 0 {
                    Text("복습 \(due)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.tint.opacity(0.14)))
                        .padding(.leading, 4)
                }

                Spacer()
                Text("\(notebook.wordCount)단어")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.contentPad)
        .glassPanel()
        .contentShape(Rectangle())
    }
}
