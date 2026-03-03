import SwiftUI
import SwiftData
import UserNotifications
import Combine

// MARK: - NotificationManager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // 알림 권한 요청
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("알림 권한 요청 실패: \(error)")
            return false
        }
    }
    
    // 현재 권한 상태 확인
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // 루틴 알림 예약
    func scheduleRoutineNotification(for routine: Routine) async {
        guard let notificationTime = routine.notificationTime else { return }
        
        // 기존 알림 취소
        await cancelRoutineNotifications(for: routine)
        
        let center = UNUserNotificationCenter.current()
        
        // 루틴이 반복되는 요일들에 대해 알림 설정
        for weekday in routine.repeatDays {
            let content = UNMutableNotificationContent()
            content.title = "루틴 알림"
            content.body = "\(routine.title) 시간이에요!"
            content.sound = .default
            
            // 아이콘이 있으면 표시
            if let icon = routine.icon {
                content.subtitle = "\(icon) \(routine.timeBlock.displayName)"
            } else {
                content.subtitle = routine.timeBlock.displayName
            }
            
            // 날짜 컴포넌트 생성 (iOS 요일: 1=일요일, 2=월요일...)
            var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
            dateComponents.weekday = weekday + 1 // 0-6을 1-7로 변환
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let identifier = "routine_\(routine.id.uuidString)_\(weekday)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                try await center.add(request)
                print("알림 예약 성공: \(routine.title) - \(weekdayName(weekday))")
            } catch {
                print("알림 예약 실패: \(error)")
            }
        }
    }
    
    // 루틴 알림 취소
    func cancelRoutineNotifications(for routine: Routine) async {
        let center = UNUserNotificationCenter.current()
        
        // 해당 루틴의 모든 알림 식별자 생성
        let identifiers = routine.repeatDays.map { weekday in
            "routine_\(routine.id.uuidString)_\(weekday)"
        }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("알림 취소 완료: \(routine.title)")
    }
    
    // 모든 루틴 알림 다시 설정
    func rescheduleAllRoutineNotifications(routines: [Routine]) async {
        // 모든 기존 알림 취소
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // 권한 확인
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            print("알림 권한이 없습니다")
            return
        }
        
        // 알림이 설정된 루틴들만 다시 예약
        let routinesWithNotifications = routines.filter { $0.notificationTime != nil }
        
        for routine in routinesWithNotifications {
            await scheduleRoutineNotification(for: routine)
        }
        
        print("모든 루틴 알림 재설정 완료: \(routinesWithNotifications.count)개")
    }
    
    // 요일 이름 반환
    private func weekdayName(_ weekday: Int) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return names[safe: weekday] ?? "알 수 없음"
    }
}

// Array 안전 접근을 위한 extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

@main
struct DailyStackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Routine.self,
            DailyLog.self,
            Todo.self
        ])
        
        // 개발 중에만 데이터베이스 재설정 (스키마 변경 시)
        #if DEBUG
        clearExistingDatabase()
        #endif
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("ModelContainer 생성 성공")
            return container
        } catch {
            print("ModelContainer 생성 실패: \(error)")
            fatalError("데이터베이스 초기화 실패")
        }
    }()
    
    static func clearExistingDatabase() {
        print("데이터베이스 파일들을 정리합니다...")
        let fileManager = FileManager.default
        
        // SwiftData가 사용하는 주요 경로들
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Documents 디렉토리를 찾을 수 없습니다")
            return
        }
        
        // SwiftData 관련 파일들 삭제
        let filesToDelete = [
            "default.store",
            "default.store-wal", 
            "default.store-shm",
            ".default.store",
            ".default.store-wal",
            ".default.store-shm"
        ]
        
        for fileName in filesToDelete {
            let fileURL = documentsURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    print("삭제된 파일: \(fileName)")
                } catch {
                    print("파일 삭제 실패: \(fileName) - \(error)")
                }
            }
        }
        
        print("데이터베이스 정리 완료")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    cleanupOldTodos()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // 앱 시작 시 이전 날 완료된 Todo들 정리
    private func cleanupOldTodos() {
        let context = sharedModelContainer.mainContext
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        do {
            // 완료된 Todo들을 가져와서 필터링
            let todoDescriptor = FetchDescriptor<Todo>(
                predicate: #Predicate<Todo> { todo in
                    todo.isCompleted == true
                }
            )
            let completedTodos = try context.fetch(todoDescriptor)
            
            // 오늘 이전에 완료된 Todo들 찾기
            let todosToDelete = completedTodos.filter { todo in
                guard let completedAt = todo.completedAt else { return false }
                let completedDay = calendar.startOfDay(for: completedAt)
                return completedDay < today
            }
            
            // 삭제
            for todo in todosToDelete {
                context.delete(todo)
            }
            
            if !todosToDelete.isEmpty {
                try context.save()
                print("정리된 이전 날 완료 Todo: \(todosToDelete.count)개")
            }
            
            // 루틴 알림 설정
            setupNotifications(context: context)
            
        } catch {
            print("앱 초기화 중 오류: \(error)")
        }
    }
    
    // 알림 설정
    private func setupNotifications(context: ModelContext) {
        Task {
            do {
                let routineDescriptor = FetchDescriptor<Routine>()
                let routines = try context.fetch(routineDescriptor)
                
                // 모든 루틴 알림 재설정
                await NotificationManager.shared.rescheduleAllRoutineNotifications(routines: routines)
            } catch {
                print("루틴 알림 설정 중 오류: \(error)")
            }
        }
    }
}
