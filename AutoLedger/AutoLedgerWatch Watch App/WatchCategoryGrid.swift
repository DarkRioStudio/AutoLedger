import SwiftUI

struct WatchCategoryGrid: View {
    let options: [WatchCategoryOption]
    @Binding var selection: String

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection == option.rawValue
                Button {
                    selection = option.rawValue
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: option.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(height: 19)
                            .accessibilityHidden(true)
                        Text(option.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
                    .background(
                        isSelected ? Color.secondary.opacity(0.22) : Color.secondary.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? Color.secondary : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}
