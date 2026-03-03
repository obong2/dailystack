import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checkmark.square")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }

            ManageView()
                .tabItem {
                    Label("Manage", systemImage: "list.bullet")
                }
        }
        .tint(Color.dsBlue)
    }
}

#Preview {
    ContentView()
}
