//
//  ContentView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Root TabView. Three tabs mirroring the bottom-of-mockup layout:
/// Today, Progress, Roadmap.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            RoadmapView()
                .tabItem {
                    Label("Roadmap", systemImage: "map.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            SampleData.seedIfNeeded(context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSupport.container)
}
