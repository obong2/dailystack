import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var allLogs: [DailyLog]
    @Query private var allRoutines: [Routine]

    @State private var selectedDate: Date? = nil
    @State private var showingPopover = false

    // 날짜별 완료율 딕셔너리
    private var heatmapData: [Date: Double] {
        let calendar = Calendar.current
        var result: [Date: Double] = [:]

        let logsByDate = Dictionary(grouping: allLogs) { log in
            calendar.startOfDay(for: log.date)
        }

        for (date, logs) in logsByDate {
            // 해당 날짜에 스케줄된 루틴 수 계산 (요일 기반)
            let weekday = calendar.component(.weekday, from: date) - 1
            let scheduledCount = allRoutines.filter { $0.repeatDays.contains(weekday) }.count
            guard scheduledCount > 0 else { continue }

            let completed = logs.filter { $0.isCompleted }.count
            result[date] = Double(completed) / Double(scheduledCount)
        }

        return result
    }

    // 선택된 날짜의 완료된 루틴
    private var completedRoutinesForSelected: [String] {
        guard let date = selectedDate else { return [] }
        let calendar = Calendar.current

        return allLogs
            .filter { log in
                calendar.isDate(log.date, inSameDayAs: date) && log.isCompleted
            }
            .compactMap { log in
                allRoutines.first { $0.id == log.routineId }?.title
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 섹션 타이틀
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(.label))
                        Text("최근 8주 완료 패턴")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .padding(.top, 16)

                    // 히트맵
                    HeatmapView(data: heatmapData) { date in
                        selectedDate = date
                        showingPopover = true
                    }
                    .padding(.bottom, 8)

                    // 통계 요약
                    statsSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingPopover) {
                if let date = selectedDate {
                    DayDetailSheet(date: date, completedRoutines: completedRoutinesForSelected)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        let last7 = last7DaysRate
        let last30 = last30DaysRate

        return HStack(spacing: 16) {
            StatCard(title: "7일 평균", value: "\(Int(last7 * 100))%", color: Color.dsBlue)
            StatCard(title: "30일 평균", value: "\(Int(last30 * 100))%", color: Color.dsBlue)
        }
    }

    private var last7DaysRate: Double {
        rateForDays(7)
    }

    private var last30DaysRate: Double {
        rateForDays(30)
    }

    private func rateForDays(_ days: Int) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return 0 }

        var total = 0
        var completed = 0

        var current = start
        while current <= today {
            let weekday = calendar.component(.weekday, from: current) - 1
            let scheduled = allRoutines.filter { $0.repeatDays.contains(weekday) }.count
            total += scheduled

            let dayCompleted = allLogs.filter {
                calendar.isDate($0.date, inSameDayAs: current) && $0.isCompleted
            }.count
            completed += dayCompleted

            current = calendar.date(byAdding: .day, value: 1, to: current) ?? today
        }

        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let date: Date
    let completedRoutines: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 핸들 + 날짜
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Text(date.formatted(.dateTime.month().day()))
                        .font(.title2.bold())
                        .foregroundStyle(Color(.label))
                }
                Spacer()
                Button("닫기") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Color.dsBlue)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Divider()

            if completedRoutines.isEmpty {
                Text("완료한 루틴이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(completedRoutines, id: \.self) { title in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.dsBlue)
                                Text(title)
                                    .font(.body)
                                    .foregroundStyle(Color(.label))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }

            Spacer()
        }
    }
}
