import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var routineId: UUID
    var date: Date          // 날짜만 (시간 제거)
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        routineId: UUID,
        date: Date
    ) {
        self.id = id
        self.routineId = routineId
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = nil
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    func toggle() {
        if completedAt != nil {
            completedAt = nil
        } else {
            completedAt = Date()
        }
    }
}

// MARK: - Helper

extension DailyLog {
    /// 완료율 계산 헬퍼 (히트맵용)
    static func completionRate(logs: [DailyLog], on date: Date) -> Double {
        let dayLogs = logs.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        guard !dayLogs.isEmpty else { return 0 }
        let completed = dayLogs.filter { $0.isCompleted }.count
        return Double(completed) / Double(dayLogs.count)
    }
}
