import SwiftUI

struct AddWaterSheet: View {
    var onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 300

    private let presets: [(ml: Int, name: LocalizedStringKey)] = [(200, "Cup"), (330, "Can"), (750, "Flask")]

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Int(amount), format: .number)
                        .font(.system(size: 64, weight: .heavy))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: amount))
                    Text("ml")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                .animation(.snappy, value: amount)

                Slider(value: $amount, in: 50...1000, step: 10)
                    .sensoryFeedback(.selection, trigger: Int(amount) / 50)
                    .accessibilityLabel("Amount")
                    .accessibilityValue("\(Int(amount)) millilitres")

                HStack(spacing: 10) {
                    ForEach(presets, id: \.ml) { preset in
                        let selected = Int(amount) == preset.ml
                        Button {
                            withAnimation(.snappy) { amount = Double(preset.ml) }
                        } label: {
                            VStack(spacing: 2) {
                                Text(preset.ml, format: .number)
                                    .font(.headline.weight(.heavy))
                                Text(preset.name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .foregroundStyle(selected ? Color.accentColor : Color.primary)
                            .background(
                                selected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    onAdd(Int(amount))
                    dismiss()
                } label: {
                    LargeActionLabel(title: "Add \(Int(amount)) ml")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .navigationTitle("Add Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

#Preview {
    Text("Today")
        .sheet(isPresented: .constant(true)) {
            AddWaterSheet { _ in }
                .presentationDetents([.medium])
        }
        .fontDesign(.rounded)
}
