import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Routine> { _ in true })
    private var rawRoutines: [Routine]
    
    // 수동으로 정렬된 루틴
    private var allRoutines: [Routine] {
        rawRoutines.sorted { lhs, rhs in
            if lhs.timeBlock != rhs.timeBlock {
                return lhs.timeBlock < rhs.timeBlock
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    @Query private var allLogs: [DailyLog]
    @Query(filter: #Predicate<Todo> { todo in !todo.isCompleted }) private var pendingTodos: [Todo]
    @Query(filter: #Predicate<Todo> { todo in todo.isCompleted }) private var completedTodos: [Todo]

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    // 오늘 표시해야 할 루틴 (요일 필터)
    private var todayRoutines: [Routine] {
        allRoutines.filter { $0.isScheduledToday }
    }

    // 블록별 분류
    private func routines(for block: TimeBlock) -> [Routine] {
        todayRoutines
            .filter { $0.timeBlock == block }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // 오늘 로그 가져오기
    private func log(for routine: Routine) -> DailyLog? {
        allLogs.first {
            $0.routineId == routine.id &&
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    // 오늘 진행률 (루틴 + 투두)
    private var completionProgress: Double {
        let routineTotal = todayRoutines.count
        let todoTotal = pendingTodos.count + completedTodos.count
        let total = routineTotal + todoTotal
        
        guard total > 0 else { return 0 }
        
        let routineDone = todayRoutines.filter { log(for: $0)?.isCompleted == true }.count
        let todoDone = completedTodos.count
        let done = routineDone + todoDone
        
        return Double(done) / Double(total)
    }
    
    // 인사이트 생성
    private var todayInsight: String? {
        return InsightEngine.generateInsight(
            allRoutines: allRoutines,
            allLogs: allLogs,
            todayRoutines: todayRoutines,
            pendingTodos: pendingTodos,
            completedTodos: completedTodos,
            today: today
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 날짜 헤더
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    // 인사이트 배너
                    if let insight = todayInsight {
                        insightBanner(insight)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }

                    // 투두 섹션 (항상 표시)
                    todoSection
                    
                    // 블록별 섹션
                    if todayRoutines.isEmpty && pendingTodos.isEmpty && completedTodos.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(TimeBlock.allCases, id: \.self) { block in
                            let blockRoutines = routines(for: block)
                            if !blockRoutines.isEmpty {
                                blockSection(block: block, routines: blockRoutines)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showingEditTodo) {
                if let todo = editingTodo {
                    EditTodoView(todo: todo)
                        .environment(\.modelContext, modelContext)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide)))
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))

            Text(Date().formatted(.dateTime.month().day()))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color(.label))

            if !todayRoutines.isEmpty {
                // 진행률 바
                ProgressView(value: completionProgress)
                    .tint(Color.dsBlue)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Block Section

    private func blockSection(block: TimeBlock, routines: [Routine]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 섹션 헤더
            HStack(spacing: 6) {
                Image(systemName: block.sfSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))
                Text(block.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // 루틴 행들
            let (pending, completed) = splitByCompletion(routines)

            ForEach(pending) { routine in
                routineRow(routine: routine)
                Divider()
                    .padding(.leading, routine.icon != nil ? 58 : 20)
            }

            if !completed.isEmpty {
                ForEach(completed) { routine in
                    routineRow(routine: routine)
                    if routine.id != completed.last?.id {
                        Divider()
                            .padding(.leading, routine.icon != nil ? 58 : 20)
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }

    private func routineRow(routine: Routine) -> some View {
        RoutineRowView(routine: routine, log: log(for: routine)) {
            toggleRoutine(routine)
        }
    }

    private func splitByCompletion(_ routines: [Routine]) -> ([Routine], [Routine]) {
        let pending = routines.filter { log(for: $0)?.isCompleted != true }
        let completed = routines.filter { log(for: $0)?.isCompleted == true }
        return (pending, completed)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.separator)

            Text("할 일이 없어요")
                .font(.headline)
                .foregroundStyle(Color(.secondaryLabel))

            Text("루틴은 Manage 탭에서, 할 일은 + 버튼으로 추가해보세요")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Actions

    private func toggleRoutine(_ routine: Routine) {
        let existingLog = log(for: routine)

        if let existingLog {
            existingLog.toggle()
        } else {
            // 새 로그 생성
            let newLog = DailyLog(routineId: routine.id, date: today)
            newLog.completedAt = Date()
            modelContext.insert(newLog)
        }

        try? modelContext.save()
    }
    
    // MARK: - Todo Section
    
    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 섹션 헤더
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))
                Text("할 일")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabel))
                
                Spacer()
                
                Button {
                    showingAddTodo = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.dsBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // 미완료 투두들
            ForEach(pendingTodos.sorted(by: { $0.createdAt < $1.createdAt })) { todo in
                TodoRowView(todo: todo, onToggle: {
                    toggleTodo(todo)
                }, onEdit: {
                    editingTodo = todo
                    showingEditTodo = true
                })
                if todo.id != pendingTodos.last?.id || !completedTodos.isEmpty {
                    Divider()
                        .padding(.leading, 20)
                }
            }
            
            // 완료된 투두들
            ForEach(completedTodos.sorted(by: { $0.completedAt ?? Date() > $1.completedAt ?? Date() })) { todo in
                TodoRowView(todo: todo, onToggle: {
                    toggleTodo(todo)
                }, onEdit: {
                    editingTodo = todo
                    showingEditTodo = true
                })
                if todo.id != completedTodos.last?.id {
                    Divider()
                        .padding(.leading, 20)
                }
            }
        }
        .padding(.bottom, 16)
    }
    
    @State private var showingAddTodo = false
    @State private var showingEditTodo = false
    @State private var editingTodo: Todo? = nil
    
    private func toggleTodo(_ todo: Todo) {
        todo.toggle()
        
        // 완료되면 3초 후 자동 삭제
        if todo.isCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    modelContext.delete(todo)
                    try? modelContext.save()
                }
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Insight Banner
    
    private func insightBanner(_ insight: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.orange)
            
            Text(insight)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - AddTodoView

struct AddTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var priority = TodoPriority.normal
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("할 일을 입력하세요", text: $title)
                        .font(.body)
                }
                
                Section("우선순위") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TodoPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("마감일 설정", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "마감일",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("새 할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundStyle(Color(.label))
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("저장") {
                        saveTodo()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dsBlue)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveTodo() {
        let newTodo = Todo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority
        )
        
        modelContext.insert(newTodo)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - TodoRowView

struct TodoRowView: View {
    let todo: Todo
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    private var isOverdue: Bool {
        guard let dueDate = todo.dueDate, !todo.isCompleted else { return false }
        return dueDate < Date()
    }
    
    private var dueDateText: String? {
        guard let dueDate = todo.dueDate else { return nil }
        let formatter = DateFormatter()
        
        if Calendar.current.isDate(dueDate, inSameDayAs: Date()) {
            formatter.timeStyle = .short
            return "오늘 \(formatter.string(from: dueDate))"
        } else if Calendar.current.isDate(dueDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
            formatter.timeStyle = .short
            return "내일 \(formatter.string(from: dueDate))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: dueDate)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 우선순위 표시
            Circle()
                .fill(todo.priority.color)
                .frame(width: 8, height: 8)
                .opacity(todo.isCompleted ? 0.3 : 1.0)

            // 제목과 마감일
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.body)
                    .foregroundColor(todo.isCompleted ? Color(.secondaryLabel) : Color(.label))
                    .strikethrough(todo.isCompleted, color: Color(.secondaryLabel))
                    .animation(.easeInOut(duration: 0.2), value: todo.isCompleted)
                
                if let dueDateText = dueDateText {
                    Text(dueDateText)
                        .font(.caption)
                        .foregroundColor(isOverdue ? .red : Color(.secondaryLabel))
                }
            }

            Spacer()

            // 체크박스
            TodoCheckboxButton(isCompleted: todo.isCompleted, onToggle: onToggle)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("편집", systemImage: "pencil")
            }
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

// MARK: - Todo Checkbox Button

struct TodoCheckboxButton: View {
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            // 햅틱
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onToggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isCompleted ? Color.dsBlue : Color.separator, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCompleted ? Color.dsBlue : Color.clear)
                    )
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isCompleted)
    }
}

// MARK: - EditTodoView

struct EditTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let todo: Todo
    
    @State private var title: String
    @State private var priority: TodoPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    
    init(todo: Todo) {
        self.todo = todo
        self._title = State(initialValue: todo.title)
        self._priority = State(initialValue: todo.priority)
        self._hasDueDate = State(initialValue: todo.dueDate != nil)
        self._dueDate = State(initialValue: todo.dueDate ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("할 일을 입력하세요", text: $title)
                        .font(.body)
                }
                
                Section("우선순위") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TodoPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 12, height: 12)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("마감일 설정", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "마감일",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        deleteTodo()
                    } label: {
                        Label("삭제", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("할 일 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundStyle(Color(.label))
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("저장") {
                        saveTodo()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.dsBlue)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveTodo() {
        todo.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.priority = priority
        todo.dueDate = hasDueDate ? dueDate : nil
        
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteTodo() {
        modelContext.delete(todo)
        try? modelContext.save()
        dismiss()
    }
}
