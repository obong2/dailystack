import SwiftUI
import SwiftData

struct AddEditRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 편집 모드일 때 기존 루틴을 전달
    let editingRoutine: Routine?

    @State private var title: String = ""
    @State private var selectedBlock: TimeBlock = .morning
    @State private var repeatDays: Set<Int> = Set(0...6)
    @State private var icon: String = ""
    @State private var showingIconPicker = false
    @State private var enableNotification: Bool = false
    @State private var notificationTime: Date = Calendar.current.date(
        bySettingHour: 8, minute: 0, second: 0, of: Date()
    ) ?? Date()

    private var isEditing: Bool { editingRoutine != nil }

    private let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        NavigationStack {
            Form {
                // 기본 정보
                Section("루틴 이름") {
                    TextField("예: 물 마시기", text: $title)
                        .font(.body)
                }

                // 시간 블록
                Section("시간대") {
                    Picker("시간대", selection: $selectedBlock) {
                        ForEach(TimeBlock.allCases, id: \.self) { block in
                            Label(block.displayName, systemImage: block.sfSymbol)
                                .tag(block)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // 반복 요일
                Section("반복 요일") {
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { day in
                            DayToggleButton(
                                label: weekdayLabels[day],
                                isSelected: repeatDays.contains(day)
                            ) {
                                if repeatDays.contains(day) {
                                    if repeatDays.count > 1 { repeatDays.remove(day) }
                                } else {
                                    repeatDays.insert(day)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 아이콘 (선택)
                Section("아이콘") {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            if !icon.isEmpty {
                                Image(systemName: icon)
                                    .foregroundStyle(Color.dsBlue)
                                    .frame(width: 24)
                                Text(icon)
                                    .foregroundStyle(Color(.label))
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Color(.tertiaryLabel))
                                    .frame(width: 24)
                                Text("아이콘 선택")
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                            Spacer()
                            if !icon.isEmpty {
                                Button {
                                    icon = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                // 알림 (P2)
                Section("알림") {
                    Toggle("알림 사용", isOn: $enableNotification)

                    if enableNotification {
                        DatePicker("알림 시간",
                                   selection: $notificationTime,
                                   displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle(isEditing ? "루틴 편집" : "새 루틴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadExistingData() }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }

    // MARK: - Load

    private func loadExistingData() {
        guard let routine = editingRoutine else { return }
        title = routine.title
        selectedBlock = routine.timeBlock
        repeatDays = Set(routine.repeatDays)
        icon = routine.icon ?? ""
        if let time = routine.notificationTime {
            enableNotification = true
            notificationTime = time
        }
    }

    // MARK: - Save

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanIcon = icon.trimmingCharacters(in: .whitespaces)

        if let routine = editingRoutine {
            routine.title = cleanTitle
            routine.timeBlock = selectedBlock
            routine.repeatDays = Array(repeatDays).sorted()
            routine.icon = cleanIcon.isEmpty ? nil : cleanIcon
            routine.notificationTime = enableNotification ? notificationTime : nil
        } else {
            // 동일 블록 내 가장 마지막 순서
            let newRoutine = Routine(
                title: cleanTitle,
                timeBlock: selectedBlock,
                repeatDays: Array(repeatDays).sorted(),
                sortOrder: 999,
                notificationTime: enableNotification ? notificationTime : nil,
                icon: cleanIcon.isEmpty ? nil : cleanIcon
            )
            modelContext.insert(newRoutine)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Day Toggle Button

struct DayToggleButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let iconCategories = [
        IconCategory(name: "건강", icons: ["drop.fill", "heart.fill", "pills.fill", "thermometer", "lungs.fill", "brain.head.profile", "figure.walk", "figure.run"]),
        IconCategory(name: "운동", icons: ["dumbbell.fill", "figure.strengthtraining.traditional", "figure.yoga", "figure.pool.swim", "bicycle", "tennisball.fill", "basketball.fill", "soccerball"]),
        IconCategory(name: "음식", icons: ["fork.knife", "cup.and.saucer.fill", "wineglass.fill", "carrot.fill", "applelogo", "leaf.fill", "birthday.cake.fill", "takeoutbag.and.cup.and.straw.fill"]),
        IconCategory(name: "학습", icons: ["book.fill", "pencil", "graduationcap.fill", "studentdesk", "character.book.closed.fill", "brain", "lightbulb.fill", "magazine.fill"]),
        IconCategory(name: "업무", icons: ["laptopcomputer", "desktopcomputer", "briefcase.fill", "folder.fill", "doc.text.fill", "calendar", "checkmark.circle.fill", "target"]),
        IconCategory(name: "라이프", icons: ["house.fill", "bed.double.fill", "shower.fill", "toilet.fill", "washer.fill", "car.fill", "bus.fill", "airplane"]),
        IconCategory(name: "취미", icons: ["gamecontroller.fill", "music.note", "camera.fill", "paintbrush.fill", "guitars.fill", "tv.fill", "film.fill", "book.closed.fill"]),
        IconCategory(name: "자연", icons: ["sun.max.fill", "moon.stars.fill", "cloud.rain.fill", "snow", "tree.fill", "leaf", "rosette", "mountain.2.fill"])
    ]
    
    @State private var searchText = ""
    @State private var selectedCategory = 0
    
    private var filteredIcons: [String] {
        let categoryIcons = iconCategories[selectedCategory].icons
        if searchText.isEmpty {
            return categoryIcons
        } else {
            return categoryIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 카테고리 선택
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<iconCategories.count, id: \.self) { index in
                            Button {
                                selectedCategory = index
                            } label: {
                                Text(iconCategories[index].name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == index ? Color.dsBlue : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundStyle(selectedCategory == index ? .white : Color(.label))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                
                Divider()
                
                // 아이콘 그리드
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 20) {
                        ForEach(filteredIcons, id: \.self) { iconName in
                            Button {
                                selectedIcon = iconName
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 24))
                                        .foregroundStyle(selectedIcon == iconName ? .white : Color.dsBlue)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedIcon == iconName ? Color.dsBlue : Color(.secondarySystemGroupedBackground))
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .searchable(text: $searchText, prompt: "아이콘 검색")
            }
            .navigationTitle("아이콘 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
                
                if !selectedIcon.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("없음") {
                            selectedIcon = ""
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct IconCategory {
    let name: String
    let icons: [String]
}

#Preview {
    AddEditRoutineView(editingRoutine: nil)
}
