//
//  CassetteDeckTabBar.swift
//  Resonance
//
//  Custom tab bar replacing system TabView. Brushed metal control strip
//  with 5 latching mechanical buttons and LED indicators.
//

import SwiftUI

// MARK: - Cassette Deck Tab Bar

struct CassetteDeckTabBar: View {
    @Binding var selectedTab: MainView.Tab
    @Environment(\.retroAccentColor) private var accentColor
    @State private var hapticTrigger = 0

    private let tabs = MainView.Tab.allCases

    private let tabIcons: [MainView.Tab: String] = [
        .nowPlaying: "play.circle",
        .mood: "face.smiling",
        .playlists: "music.note.list",
        .insights: "chart.bar.xaxis",
        .settings: "gear"
    ]

    private let tabLabels: [MainView.Tab: String] = [
        .nowPlaying: "PLAY",
        .mood: "MOOD",
        .playlists: "LIBRARY",
        .insights: "DATA",
        .settings: "CONFIG"
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.rawValue) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.vertical, 8)
        .padding(.bottom, 4)
        .brushedMetal(cornerRadius: 0)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    private func tabButton(for tab: MainView.Tab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(RetroAnimation.traySlide)) {
                selectedTab = tab
            }
            hapticTrigger += 1
        } label: {
            VStack(spacing: 4) {
                RetroLEDIndicator(
                    isOn: isSelected,
                    color: accentColor,
                    size: 5
                )

                VStack(spacing: 2) {
                    Image(systemName: tabIcons[tab] ?? "circle")
                        .font(.system(size: 14, weight: .medium))
                    Text(tabLabels[tab] ?? "")
                        .font(.system(size: 6, weight: .heavy, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? ResonanceColors.metalDark : Color.clear)
                )
                .offset(y: isSelected ? 2 : 0)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Tab Bar") {
    @Previewable @State var tab = MainView.Tab.nowPlaying

    VStack {
        Spacer()
        CassetteDeckTabBar(selectedTab: $tab)
    }
    .background(Color.black)
}
