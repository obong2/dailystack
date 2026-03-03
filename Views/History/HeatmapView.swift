import SwiftUI

struct HeatmapView: View {
    /// 날짜별 완료율 딕셔너리 (key: 자정 기준 Date, value: 0.0~1.0)
    let data: [Date: Double]
    let onDayTap: (Date) -> Void

    private let weeks = 8
    private let calendar = Calendar.current
    private let cellSize: CGFloat = 36
    private let cellSpacing: CGFloat = 4

    /// 오늘 기준 8주치 날짜 (일요일 시작)
    private var dateGrid: [[Date?]] {
        let today = calendar.startOfDay(for: Date())

        // 이번 주 일요일 찾기
        let weekday = calendar.component(.weekday, from: today) - 1 // 0=일
        guard let thisSunday = calendar.date(byAdding: .day, value: -weekday, to: today),
              let startSunday = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisSunday)
        else { return [] }

        var grid: [[Date?]] = []
        for week in 0..<weeks {
            var row: [Date?] = []
            for day in 0..<7 {
                let offset = week * 7 + day
                if let date = calendar.date(byAdding: .day, value: offset, to: startSunday) {
                    row.append(date <= today ? date : nil)
                } else {
                    row.append(nil)
                }
            }
            grid.append(row)
        }
        return grid
    }

    private let dayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 요일 레이블
            HStack(spacing: cellSpacing) {
                Spacer().frame(width: 28) // 월 레이블 공간
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: cellSize)
                }
            }

            // 주간 그리드
            ForEach(0..<dateGrid.count, id: \.self) { weekIdx in
                let week = dateGrid[weekIdx]
                HStack(spacing: cellSpacing) {
                    // 월 레이블 (해당 주에 월이 바뀌면 표시)
                    monthLabel(for: week)
                        .frame(width: 28)

                    ForEach(0..<week.count, id: \.self) { dayIdx in
                        if let date = week[dayIdx] {
                            let rate = data[date] ?? 0
                            HeatmapCell(date: date, rate: rate) {
                                onDayTap(date)
                            }
                            .frame(width: cellSize, height: cellSize)
                        } else {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }

            // 범례
            legendView
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func monthLabel(for week: [Date?]) -> some View {
        let months = week.compactMap { $0 }.compactMap {
            calendar.component(.day, from: $0) <= 7
                ? calendar.component(.month, from: $0)
                : nil
        }
        if let month = months.first {
            Text("\(month)월")
                .font(.caption2)
                .foregroundStyle(Color.textSecondary)
        } else {
            Spacer()
        }
    }

    private var legendView: some View {
        HStack(spacing: 6) {
            Spacer()
            Text("낮음")
                .font(.caption2)
                .foregroundStyle(Color.textSecondary)

            ForEach([0.0, 0.25, 0.6, 1.0], id: \.self) { rate in
                RoundedRectangle(cornerRadius: 4)
                    .fill(heatmapColor(for: rate))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.separator, lineWidth: rate == 0 ? 1 : 0)
                    )
                    .frame(width: 14, height: 14)
            }

            Text("높음")
                .font(.caption2)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Heatmap Cell

struct HeatmapCell: View {
    let date: Date
    let rate: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 6)
                .fill(heatmapColor(for: rate))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            rate == 0 ? Color.separator : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Helper

func heatmapColor(for rate: Double) -> Color {
    switch rate {
    case 0: return .clear
    case ..<0.5: return .heatmap1
    case ..<1.0: return .heatmap2
    default: return .heatmap3
    }
}
