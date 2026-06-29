import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let accent: Color

    private let cardHeight: CGFloat = 124

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            Text(value)
                .font(.title.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .allowsTightening(true)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .allowsTightening(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: cardHeight, idealHeight: cardHeight, maxHeight: cardHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.94), accent.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}
