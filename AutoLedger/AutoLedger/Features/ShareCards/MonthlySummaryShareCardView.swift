import SwiftUI

struct MonthlySummaryShareCardView: View {
    let data: MonthlySummaryShareCardData
    let showsAmount: Bool

    var body: some View {
        ShareCardCanvas {
            VStack(alignment: .leading, spacing: 34) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("share_card.monthly.kicker")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(data.monthLabel)
                        .font(.system(size: 78, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                ShareCardMetricGrid {
                    ShareCardMetricTile(
                        titleKey: "share_card.monthly.entries",
                        value: data.transactionCountText,
                        systemImage: "list.bullet.rectangle.fill"
                    )
                    ShareCardMetricTile(
                        titleKey: "share_card.monthly.total",
                        value: showsAmount ? data.totalAmountText : String(localized: "share_card.amount_hidden"),
                        systemImage: showsAmount ? "banknote.fill" : "eye.slash.fill"
                    )
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text("share_card.monthly.top_categories")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ShareCardPalette.ink)

                    if data.categories.isEmpty {
                        Text("share_card.monthly.empty_categories")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(ShareCardPalette.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 28)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(Array(data.categories.prefix(3).enumerated()), id: \.element.id) { index, category in
                                HStack(spacing: 18) {
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 58, height: 58)
                                        .background(Circle().fill(index == 0 ? ShareCardPalette.secondary : ShareCardPalette.accent))

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(category.title)
                                            .font(.system(size: 30, weight: .bold, design: .rounded))
                                            .foregroundStyle(ShareCardPalette.ink)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Text(category.percentText)
                                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                                            .foregroundStyle(ShareCardPalette.mutedInk)
                                    }

                                    Spacer()

                                    if showsAmount {
                                        Text(category.amountText)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundStyle(ShareCardPalette.ink)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.68)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(30)
                .background(ShareCardPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))

                Text(data.summary)
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(6)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                ShareCardWatermark()
            }
        }
    }
}

private struct ShareCardMetricGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 18) {
            content()
        }
    }
}

struct ShareCardMetricTile: View {
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(ShareCardPalette.accent)

            Text(titleKey)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(ShareCardPalette.mutedInk)

            Text(value)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(ShareCardPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.56)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShareCardPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

struct ShareCardCanvas<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ShareCardPalette.accent,
                    ShareCardPalette.secondary,
                    ShareCardPalette.deep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                content()
            }
            .padding(64)
        }
    }
}

struct ShareCardWatermark: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 25, weight: .bold))
            Text("share_card.watermark")
                .font(.system(size: 25, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.82))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ShareCardPalette {
    static let accent = Color(red: 0.08, green: 0.50, blue: 0.40)
    static let secondary = Color(red: 0.19, green: 0.46, blue: 0.66)
    static let deep = Color(red: 0.08, green: 0.16, blue: 0.15)
    static let card = Color.white.opacity(0.92)
    static let ink = Color(red: 0.07, green: 0.12, blue: 0.12)
    static let mutedInk = Color(red: 0.36, green: 0.43, blue: 0.42)
}
