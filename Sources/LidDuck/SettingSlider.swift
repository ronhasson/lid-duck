import SwiftUI

// A one-unit `step` on SwiftUI's macOS Slider creates a native tick for every
// value (2,001 for transition duration). On the profiled OS this makes the first
// layout repeatedly rebuild the AppKit tick cache. Keep the control continuous;
// quantize the binding instead. The separate duration ruler stays lightweight.
struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) {
        self.title = title
        self._value = value
        self.range = range
    }
    static func rounded(_ value: Double, in range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(range.upperBound, max(range.lowerBound, value.rounded()))
    }
    var body: some View {
        Slider(value: Binding(
            get: { value },
            set: { value = Self.rounded($0, in: range) }
        ), in: range)
        .accessibilityLabel(title)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = Self.rounded(value + 1, in: range)
            case .decrement: value = Self.rounded(value - 1, in: range)
            @unknown default: break
            }
        }
    }
}
