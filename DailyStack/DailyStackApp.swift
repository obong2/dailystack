import SwiftUI
import SwiftData

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
            let descriptor = FetchDescriptor<Todo>(
                predicate: #Predicate<Todo> { todo in
                    todo.isCompleted == true
                }
            )
            let completedTodos = try context.fetch(descriptor)
            
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
        } catch {
            print("Todo 정리 중 오류: \(error)")
        }
    }
}
