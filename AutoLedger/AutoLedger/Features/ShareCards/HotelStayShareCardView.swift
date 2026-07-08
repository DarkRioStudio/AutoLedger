import SwiftUI

struct HotelStayShareCardView: View {
    let data: HotelStayShareCardData
    let showsPrice: Bool

    var body: some View {
        ShareCardCanvas {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("share_card.hotel.kicker")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(data.hotelName)
                        .font(.system(size: 66, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)
                }

                VStack(alignment: .leading, spacing: 18) {
                    Label(data.locationText, systemImage: "mappin.and.ellipse")
                    Label(data.dateRangeText, systemImage: "calendar")
                    Label(data.nightsText, systemImage: "moon.fill")
                    if !data.roomTypeText.isEmpty {
                        Label(data.roomTypeText, systemImage: "bed.double.fill")
                    }
                }
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(ShareCardPalette.ink)
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ShareCardPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))

                ShareCardMetricTile(
                    titleKey: "share_card.hotel.price",
                    value: showsPrice ? data.priceText : String(localized: "share_card.amount_hidden"),
                    systemImage: showsPrice ? "creditcard.fill" : "eye.slash.fill"
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text("share_card.hotel.review_title")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(data.reviewText)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .lineLimit(4)
                        .minimumScaleFactor(0.72)
                }
                .padding(.top, 4)

                Spacer(minLength: 0)

                ShareCardWatermark()
            }
        }
    }
}
