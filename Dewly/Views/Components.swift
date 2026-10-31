import SwiftUI

// MARK: - Progress ring

/// Activity-style ring. Animates on a spring whenever `progress` changes,
/// and retargets mid-flight if you tap again before it settles.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - Brand mark

/// The Dewly mark: a ring with a calm water line.
struct LevelMark: View {
    var color: Color = .white

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(color, lineWidth: size * 0.09)
                    .frame(width: size * 0.68, height: size * 0.68)
                Circle()
                    .fill(color)
                    .frame(width: size * 0.6, height: size * 0.6)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: size * 0.6 * 0.37)
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct AppMark: View {
    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: proxy.size.width * 0.235, style: .continuous)
                .fill(Color.accentColor)
                .overlay { LevelMark().padding(proxy.size.width * 0.12) }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Buttons

/// Rounded capsule button that shrinks the instant it's touched.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(prominent ? Color.white : Color.accentColor)
            .background(prominent ? Color.accentColor : Color.accentColor.opacity(0.15), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct LargeActionLabel: View {
    var title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .frame(maxWidth: .infinity, minHeight: 50)
    }
}

// MARK: - Cards & badges

extension View {
    /// Inset-grouped style card.
    func card() -> some View {
        background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct SectionHeader: View {
    var title: LocalizedStringKey
    var detail: String?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let detail {
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.weight(.heavy))
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }
}

struct StreakBadge: View {
    var count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text(count, format: .number)
                .contentTransition(.numericText(value: Double(count)))
        }
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(Color.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.15), in: Capsule())
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) day streak")
    }
}

// MARK: - Undo toast

struct UndoToast: View {
    var entry: DrinkEntry
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Added \(entry.ml) ml")
                .font(.subheadline.weight(.bold))
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.heavy))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85), in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }
}

// MARK: - Formatting

extension DrinkEntry {
    var name: String {
        switch ml {
        case ..<201: "Cup"
        case ..<301: "Glass"
        case ..<401: "Can"
        case ..<551: "Bottle"
        default: "Flask"
        }
    }
}
