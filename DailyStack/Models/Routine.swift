import Foundation
import SwiftData
import SwiftUI

enum TimeBlock: String, Codable, CaseIterable, Comparable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"

    var displayName: String {
        switch self {
        case .morning: return "아침"
        case .afternoon: return "오후"
        case .evening: return "저녁"
        }
    }

    var sfSymbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }

    var sortIndex: Int {
        switch self {
        case .morning: return 0
        case .afternoon: return 1
        case .evening: return 2
        }
    }
    
    static func < (lhs: TimeBlock, rhs: TimeBlock) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

@Model
final class Routine {
    var id: UUID
    var title: String
    var timeBlock: TimeBlock
    var repeatDays: [Int]   // 0=일, 1=월 ... 6=토
    var sortOrder: Int
    var notificationTime: Date?
    var createdAt: Date
    var icon: String?       // SF Symbol name (optional)

    init(
        id: UUID = UUID(),
        title: String,
        timeBlock: TimeBlock,
        repeatDays: [Int] = Array(0...6),
        sortOrder: Int = 0,
        notificationTime: Date? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.timeBlock = timeBlock
        self.repeatDays = repeatDays
        self.sortOrder = sortOrder
        self.notificationTime = notificationTime
        self.createdAt = Date()
        self.icon = icon
    }

    /// 오늘 요일에 반복해야 하는지 여부 (0=일요일)
    var isScheduledToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date()) - 1
        return repeatDays.contains(weekday)
    }
}

@Model
final class Todo {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var priority: TodoPriority
    
    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: TodoPriority = .normal
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.completedAt = nil
        self.dueDate = dueDate
        self.priority = priority
    }
    
    func toggle() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}

enum TodoPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "낮음"
        case .normal: return "보통"
        case .high: return "높음"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return Color.gray
        case .normal: return Color.dsBlue
        case .high: return Color.red
        }
    }
}

// MARK: - Insight Engine

struct InsightEngine {
    static func generateInsight(
        allRoutines: [Routine],
        allLogs: [DailyLog],
        todayRoutines: [Routine],
        pendingTodos: [Todo],
        completedTodos: [Todo],
        today: Date
    ) -> String? {
        let calendar = Calendar.current
        
        // 인사이트 타입들을 시도해보고 가장 의미있는 것 반환
        if let weeklyImprovement = generateWeeklyImprovementInsight(allRoutines: allRoutines, allLogs: allLogs, today: today, calendar: calendar) {
            return weeklyImprovement
        }
        
        if let streakInsight = generateStreakInsight(allRoutines: allRoutines, allLogs: allLogs, today: today, calendar: calendar) {
            return streakInsight
        }
        
        if let consistencyInsight = generateConsistencyInsight(allRoutines: allRoutines, allLogs: allLogs, today: today, calendar: calendar) {
            return consistencyInsight
        }
        
        if let timeBlockInsight = generateTimeBlockInsight(allRoutines: allRoutines, allLogs: allLogs, today: today, calendar: calendar) {
            return timeBlockInsight
        }
        
        if let motivationalInsight = generateMotivationalInsight(todayRoutines: todayRoutines, allLogs: allLogs, pendingTodos: pendingTodos, completedTodos: completedTodos, today: today, calendar: calendar) {
            return motivationalInsight
        }
        
        return nil
    }
    
    // 주간 개선율 인사이트
    static func generateWeeklyImprovementInsight(allRoutines: [Routine], allLogs: [DailyLog], today: Date, calendar: Calendar) -> String? {
        guard !allRoutines.isEmpty else { return nil }
        
        // 이번 주와 지난 주 완료율 계산
        let thisWeekRate = getWeekCompletionRate(routines: allRoutines, logs: allLogs, weekStarting: getStartOfWeek(for: today, calendar: calendar), calendar: calendar)
        let lastWeekRate = getWeekCompletionRate(routines: allRoutines, logs: allLogs, weekStarting: getStartOfWeek(for: calendar.date(byAdding: .weekOfYear, value: -1, to: today) ?? today, calendar: calendar), calendar: calendar)
        
        guard thisWeekRate > 0 && lastWeekRate > 0 else { return nil }
        
        let improvement = thisWeekRate - lastWeekRate
        let percentImprovement = Int(improvement * 100)
        
        if percentImprovement >= 10 {
            return "이번 주 완료율이 지난 주보다 \(percentImprovement)% 높아요"
        } else if percentImprovement <= -10 {
            return "지난 주보다 \(abs(percentImprovement))% 아쉽지만 오늘부터 다시 시작"
        }
        
        return nil
    }
    
    // 연속 완료 인사이트
    static func generateStreakInsight(allRoutines: [Routine], allLogs: [DailyLog], today: Date, calendar: Calendar) -> String? {
        guard !allRoutines.isEmpty else { return nil }
        
        let streak = getCurrentStreak(routines: allRoutines, logs: allLogs, today: today, calendar: calendar)
        
        if streak >= 7 {
            return "\(streak)일 연속 완료 중입니다"
        } else if streak >= 3 {
            return "\(streak)일 연속 달성"
        }
        
        return nil
    }
    
    // 일관성 인사이트
    static func generateConsistencyInsight(allRoutines: [Routine], allLogs: [DailyLog], today: Date, calendar: Calendar) -> String? {
        guard !allRoutines.isEmpty else { return nil }
        
        let last30DaysRate = getCompletionRateForDays(routines: allRoutines, logs: allLogs, days: 30, endDate: today, calendar: calendar)
        
        if last30DaysRate >= 0.8 {
            return "지난 30일 완료율 \(Int(last30DaysRate * 100))%"
        } else if last30DaysRate >= 0.6 {
            return "지난 30일 완료율 \(Int(last30DaysRate * 100))%"
        }
        
        return nil
    }
    
    // 시간대별 인사이트
    static func generateTimeBlockInsight(allRoutines: [Routine], allLogs: [DailyLog], today: Date, calendar: Calendar) -> String? {
        let morningRate = getTimeBlockCompletionRate(routines: allRoutines, logs: allLogs, timeBlock: .morning, days: 7, endDate: today, calendar: calendar)
        let afternoonRate = getTimeBlockCompletionRate(routines: allRoutines, logs: allLogs, timeBlock: .afternoon, days: 7, endDate: today, calendar: calendar)
        let eveningRate = getTimeBlockCompletionRate(routines: allRoutines, logs: allLogs, timeBlock: .evening, days: 7, endDate: today, calendar: calendar)
        
        let rates = [
            ("아침", morningRate),
            ("오후", afternoonRate),
            ("저녁", eveningRate)
        ].filter { $0.1 > 0 }
        
        guard !rates.isEmpty else { return nil }
        
        let bestTimeBlock = rates.max { $0.1 < $1.1 }
        let worstTimeBlock = rates.min { $0.1 < $1.1 }
        
        if let best = bestTimeBlock, let worst = worstTimeBlock, best.1 - worst.1 >= 0.3 {
            return "\(best.0) 루틴이 \(worst.0)보다 \(Int((best.1 - worst.1) * 100))% 더 잘됨"
        }
        
        return nil
    }
    
    // 동기부여 인사이트 (루틴 + Todo 통합)
    static func generateMotivationalInsight(todayRoutines: [Routine], allLogs: [DailyLog], pendingTodos: [Todo], completedTodos: [Todo], today: Date, calendar: Calendar) -> String? {
        // 루틴 완료 수 계산
        let routineCompleted = todayRoutines.filter { routine in
            allLogs.contains { log in
                log.routineId == routine.id &&
                calendar.isDate(log.date, inSameDayAs: today) &&
                log.isCompleted
            }
        }.count
        
        // Todo 완료 수
        let todoCompleted = completedTodos.count
        
        // 전체 통계
        let totalTasks = todayRoutines.count + pendingTodos.count + completedTodos.count
        let totalCompleted = routineCompleted + todoCompleted
        
        guard totalTasks > 0 else {
            if calendar.component(.hour, from: Date()) < 12 {
                return "새로운 하루의 시작"
            }
            return nil
        }
        
        if totalCompleted == totalTasks {
            return "오늘 모든 할일 완료"
        } else if totalCompleted >= Int(Double(totalTasks) * 0.7) {
            return "오늘 \(totalCompleted)/\(totalTasks) 완료"
        } else if calendar.component(.hour, from: Date()) < 12 {
            return "새로운 하루의 시작"
        }
        
        return nil
    }
    
    // 헬퍼 함수들
    static func getStartOfWeek(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    static func getWeekCompletionRate(routines: [Routine], logs: [DailyLog], weekStarting: Date, calendar: Calendar) -> Double {
        var totalScheduled = 0
        var totalCompleted = 0
        
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: weekStarting) else { continue }
            let weekday = calendar.component(.weekday, from: day) - 1
            
            let dayRoutines = routines.filter { $0.repeatDays.contains(weekday) }
            totalScheduled += dayRoutines.count
            
            let dayCompleted = logs.filter { log in
                calendar.isDate(log.date, inSameDayAs: day) && log.isCompleted
            }.count
            totalCompleted += dayCompleted
        }
        
        guard totalScheduled > 0 else { return 0 }
        return Double(totalCompleted) / Double(totalScheduled)
    }
    
    static func getCurrentStreak(routines: [Routine], logs: [DailyLog], today: Date, calendar: Calendar) -> Int {
        var streak = 0
        var currentDate = today
        
        while true {
            let weekday = calendar.component(.weekday, from: currentDate) - 1
            let scheduledRoutines = routines.filter { $0.repeatDays.contains(weekday) }
            guard !scheduledRoutines.isEmpty else {
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                continue
            }
            
            let completedCount = logs.filter { log in
                calendar.isDate(log.date, inSameDayAs: currentDate) && log.isCompleted
            }.count
            
            let completionRate = Double(completedCount) / Double(scheduledRoutines.count)
            if completionRate >= 0.8 { // 80% 이상 완료하면 연속으로 인정
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    static func getCompletionRateForDays(routines: [Routine], logs: [DailyLog], days: Int, endDate: Date, calendar: Calendar) -> Double {
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else { return 0 }
        
        var totalScheduled = 0
        var totalCompleted = 0
        var currentDate = startDate
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate) - 1
            let dayRoutines = routines.filter { $0.repeatDays.contains(weekday) }
            totalScheduled += dayRoutines.count
            
            let dayCompleted = logs.filter { log in
                calendar.isDate(log.date, inSameDayAs: currentDate) && log.isCompleted
            }.count
            totalCompleted += dayCompleted
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        guard totalScheduled > 0 else { return 0 }
        return Double(totalCompleted) / Double(totalScheduled)
    }
    
    static func getTimeBlockCompletionRate(routines: [Routine], logs: [DailyLog], timeBlock: TimeBlock, days: Int, endDate: Date, calendar: Calendar) -> Double {
        let blockRoutines = routines.filter { $0.timeBlock == timeBlock }
        guard !blockRoutines.isEmpty else { return 0 }
        
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else { return 0 }
        
        var totalScheduled = 0
        var totalCompleted = 0
        var currentDate = startDate
        
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate) - 1
            let dayBlockRoutines = blockRoutines.filter { $0.repeatDays.contains(weekday) }
            totalScheduled += dayBlockRoutines.count
            
            let dayCompleted = logs.filter { log in
                calendar.isDate(log.date, inSameDayAs: currentDate) && 
                log.isCompleted &&
                blockRoutines.contains { $0.id == log.routineId }
            }.count
            totalCompleted += dayCompleted
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        guard totalScheduled > 0 else { return 0 }
        return Double(totalCompleted) / Double(totalScheduled)
    }
}
