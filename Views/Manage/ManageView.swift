import SwiftUI
import SwiftData

struct ManageView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var rawRoutines: [Routine]
    
    // 수동으로 정렬된 루틴
    private var routines: [Routine] {
        rawRoutines.sorted { lhs, rhs in
            if lhs.timeBlock != rhs.timeBlock {
                return lhs.timeBlock < rhs.timeBlock
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    @State private var showingAddSheet = false
    @State private var editingRoutine: Routine? = nil

    private func routines(for block: TimeBlock) -> [Routine] {
        routines.filter { $0.timeBlock == block }
    }

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(TimeBlock.allCases, id: \.self) { block in
                            let blockRoutines = routines(for: block)
                            if !blockRoutines.isEmpty {
                                Section {
                                    ForEach(blockRoutines) { routine in
                                        routineRow(routine)
                                    }
                                    .onMove { indices, newOffset in
                                        moveRoutine(block: block, from: indices, to: newOffset)
                                    }
                                    .onDelete { indices in
                                        deleteRoutine(block: block, at: indices)
                                    }
                                } header: {
                                    Label(block.displayName, systemImage: block.sfSymbol)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("루틴 관리")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.dsBlue)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .foregroundStyle(Color.dsBlue)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditRoutineView(editingRoutine: nil)
            }
            .sheet(item: $editingRoutine) { routine in
                AddEditRoutineView(editingRoutine: routine)
            }
        }
    }

    // MARK: - Row

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            if let icon = routine.icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dsBlue)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.title)
                    .font(.body)
                    .foregroundStyle(Color(.label))

                Text(repeatLabel(for: routine.repeatDays))
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            // 알림 아이콘
            if routine.notificationTime != nil {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingRoutine = routine
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(routine)
                try? modelContext.save()
            } label: {
                Label("삭제", systemImage: "trash")
            }

            Button {
                editingRoutine = routine
            } label: {
                Label("편집", systemImage: "pencil")
            }
            .tint(Color.dsBlue)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 52))
                .foregroundStyle(Color.separator)

            VStack(spacing: 6) {
                Text("루틴이 없어요")
                    .font(.headline)
                    .foregroundStyle(Color(.secondaryLabel))
                Text("+ 버튼을 눌러 첫 루틴을 만들어보세요")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Button {
                showingAddSheet = true
            } label: {
                Label("루틴 추가", systemImage: "plus")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.dsBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func repeatLabel(for days: [Int]) -> String {
        if days.count == 7 { return "매일" }
        let labels = ["일", "월", "화", "수", "목", "금", "토"]
        return days.sorted().map { labels[$0] }.joined(separator: ", ")
    }

    private func moveRoutine(block: TimeBlock, from: IndexSet, to: Int) {
        var blockRoutines = routines(for: block)
        blockRoutines.move(fromOffsets: from, toOffset: to)
        for (index, routine) in blockRoutines.enumerated() {
            routine.sortOrder = index
        }
        try? modelContext.save()
    }

    private func deleteRoutine(block: TimeBlock, at offsets: IndexSet) {
        let blockRoutines = routines(for: block)
        for index in offsets {
            modelContext.delete(blockRoutines[index])
        }
        try? modelContext.save()
    }
}

