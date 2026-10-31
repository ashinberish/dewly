import SwiftUI

struct OnboardingView: View {
    @Environment(HydrationStore.self) private var store
    @State private var goal = 2500

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            AppMark()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 10)

            Text("Set your\ndaily goal")
                .font(.largeTitle.weight(.heavy))
                .multilineTextAlignment(.center)
                .padding(.top, 28)

            Text("Pick an amount that feels right.\nYou can change it anytime.")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            HStack {
                stepButton("minus", label: "Decrease goal") { goal = max(1000, goal - 250) }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Double(goal) / 1000, format: .number.precision(.fractionLength(0...2)))
                        .font(.system(size: 64, weight: .heavy))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(goal)))
                    Text("L")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                stepButton("plus", label: "Increase goal") { goal = min(5000, goal + 250) }
            }
            .padding(.top, 44)

            Spacer()

            Button {
                store.goalML = goal
                store.hasOnboarded = true
                Task {
                    _ = await NotificationManager.shared.requestAuthorization()
                    NotificationManager.shared.reschedule(for: store)
                }
            } label: {
                LargeActionLabel(title: "Continue")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Text("Next, Dewly will ask to send you reminders.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
        .padding(28)
        .sensoryFeedback(.selection, trigger: goal)
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .frame(width: 56, height: 56)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    OnboardingView()
        .environment(HydrationStore(defaults: UserDefaults(suiteName: "dewly.onboarding.preview")!))
        .fontDesign(.rounded)
}
