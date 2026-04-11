//
//  RetroSegmentedSelector.swift
//  Resonance
//
//  Row of embossed metal buttons in shared bezel with LED indicators.
//  Active segment presses in with lit LED. Generic over Hashable selection type.
//

import SwiftUI

// MARK: - Retro Segmented Selector

struct RetroSegmentedSelector<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    @State private var hapticTrigger = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == option

                Button {
                    withAnimation(.spring(RetroAnimation.buttonPress)) {
                        selection = option
                    }
                    hapticTrigger += 1
                } label: {
                    VStack(spacing: 3) {
                        // LED above button
                        RetroLEDIndicator(
                            isOn: isSelected,
                            color: .white,
                            size: 4
                        )

                        // Button label
                        Text(label(option))
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        Rectangle()
                            .fill(AnyShapeStyle(
                                isSelected
                                    ? AnyShapeStyle(ResonanceColors.metalDark)
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [ResonanceColors.metalLight, ResonanceColors.metalMid],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                            ))
                    )
                    .overlay(alignment: .trailing) {
                        // Metal divider (except last)
                        if index < options.count - 1 {
                            Rectangle()
                                .fill(ResonanceColors.metalDark)
                                .frame(width: 1)
                        }
                    }
                    .offset(y: isSelected ? 2 : 0)
                    .animation(.spring(RetroAnimation.buttonPress), value: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(ResonanceColors.metalDark, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#Preview("Segmented Selector") {
    @Previewable @State var selected = "WEEK"

    RetroSegmentedSelector(
        selection: $selected,
        options: ["WEEK", "MONTH", "3MO", "YEAR"],
        label: { $0 }
    )
    .frame(width: 300)
    .padding(40)
    .background(ResonanceColors.metalDark)
}
