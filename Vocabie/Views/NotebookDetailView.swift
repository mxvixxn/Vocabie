import SwiftUI
import SwiftData

/// Inside a 단어장: the sets on this shelf, and how far through them the learner is.
///
/// Studying still happens a 세트 at a time — this screen only gets you to the right one.
struct NotebookDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @Bindable var notebook: Notebook

    @State private var showingNewSet = false
    @State private var showingRename = false
    @State private var confirmingDelete = false
    @State private var draftTitle = ""
    @State private var actions = SetActions()
    @State private var editMode: EditMode = .inactive

    private var sets: [VocabSet] { notebook.orderedSets }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if sets.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(notebook.title.isEmpty ? "제목 없는 단어장" : notebook.title)
        .navigationBarTitleDisplayMode(.inline)
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
                        showingNewSet = true
                    } label: {
                        Label("이 단어장에 세트 추가", systemImage: "plus")
                    }
                    if sets.count > 1 {
                        Button {
                            Haptics.soft()
                            withAnimation { editMode = .active }
                        } label: {
                            Label("세트 순서 바꾸기", systemImage: "arrow.up.arrow.down")
                        }
                    }
                    Divider()
                    Button {
                        draftTitle = notebook.title
                        showingRename = true
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    Button { archive() } label: {
                        Label("보관", systemImage: "archivebox")
                    }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("단어장 삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.title3)
                }
            }
            }
        }
        .sheet(isPresented: $showingNewSet) {
            NewSetView(notebook: notebook)
        }
        .setActionDialogs(actions)
        .alert("이름 변경", isPresented: $showingRename) {
            TextField("단어장 이름", text: $draftTitle)
            Button("취소", role: .cancel) { }
            Button("저장") { rename() }
        }
        .confirmationDialog(
            "‘\(notebook.title)’을(를) 삭제할까요?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deleteNotebook() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("세트 \(notebook.setCount)개와 단어 \(notebook.wordCount)개가 함께 사라져요. 되돌릴 수 없어요.")
        }
    }

    private var list: some View {
        List {
            Section {
                summary
                    .plainRow()
            }
            Section {
                ForEach(sets) { set in
                    SetListRow(set: set, actions: actions)
                }
                .onMove(perform: moveSets)
            } header: {
                Text("세트 \(notebook.setCount)개")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 2, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !notebook.detail.isEmpty {
                Text(notebook.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                stat("\(notebook.wordCount)", "단어")
                stat("\(notebook.totalStars)", "별")
                stat("\(Int(notebook.masteryProgress * 100))%", "완료")
                let due = notebook.dueCount()
                if due > 0 { stat("\(due)", "복습") }
            }
            ProgressView(value: notebook.masteryProgress)
                .tint(Theme.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.contentPad)
        .glassPanel()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "square.stack",
            title: "아직 세트가 없어요",
            message: "회차나 강 단위로 세트를 만들어\n이 단어장에 모아보세요.",
            actionTitle: "세트 만들기",
            actionImage: "plus"
        ) {
            Haptics.soft()
            showingNewSet = true
        }
    }

    // MARK: Actions

    /// Arranging the shelf also arranges what "이어서" offers next — the study hand-off
    /// walks this same order.
    private func moveSets(from source: IndexSet, to destination: Int) {
        Reorder.apply(sets, from: source, to: destination) { $0.order = $1 }
        notebook.touch()
        try? context.save()
    }

    private func rename() {
        let title = draftTitle.trimmed
        guard !title.isEmpty else { return }
        notebook.title = title
        notebook.touch()
        try? context.save()
        Haptics.success()
    }

    private func archive() {
        notebook.isArchived = true
        notebook.touch()
        try? context.save()
        Haptics.selection()
        dismiss()
    }

    private func deleteNotebook() {
        // Leave the screen before the object goes, or the title binding reads a
        // deleted model on the way out.
        dismiss()
        context.delete(notebook)
        try? context.save()
        Haptics.intenseError()
    }
}
