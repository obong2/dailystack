import SwiftUI
import SwiftData

struct RoutineRowView: View {
    let routine: Routine
    let log: DailyLog?
    let onToggle: () -> Void

    private var isCompleted: Bool {
        log?.isCompleted ?? false
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon (optional)
            if let icon = routine.icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isCompleted ? Color(.secondaryLabel) : Color.dsBlue)
                    .frame(width: 24)
            }

            // Title
            Text(routine.title)
                .font(.body)
                .foregroundColor(isCompleted ? Color(.secondaryLabel) : Color(.label))
                .strikethrough(isCompleted, color: Color(.secondaryLabel))
                .animation(.easeInOut(duration: 0.2), value: isCompleted)

            Spacer()

            // Checkbox
            CheckboxButton(isCompleted: isCompleted, onToggle: onToggle)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Checkbox Button

struct CheckboxButton: View {
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
