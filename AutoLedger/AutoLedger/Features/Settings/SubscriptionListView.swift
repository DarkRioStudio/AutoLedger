import AutoLedgerCore
import PhotosUI
import SwiftUI

struct SubscriptionListView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImporting = false
    private let ocrService = OCRService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.subscriptions.isEmpty {
                    emptyState
                } else {
                    upcomingSection
                    allSubscriptionsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("订阅管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.detectAndUpsertSubscriptions()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help("扫描历史账单自动识别订阅")
            }
        }
    }

    // MARK: - Upcoming

    private var upcomingSubscriptions: [Subscription] {
        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        return store.subscriptions.filter { $0.nextChargedAt <= sevenDaysLater && $0.nextChargedAt >= .now }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = upcomingSubscriptions
        if !upcoming.isEmpty {
            Text("即将扣费")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            ForEach(upcoming) { sub in
                subscriptionCard(sub, highlight: true)
            }
        }
    }

    // MARK: - All

    private var allSubscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("全部订阅")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text("\(store.subscriptions.count) 项")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            let monthlyCost = store.subscriptions.reduce(0.0) { sum, sub in
                switch sub.period {
                case .weekly:  return sum + sub.amount * 4.33
                case .monthly: return sum + sub.amount
                case .yearly:  return sum + sub.amount / 12.0
                }
            }
            Text("预估月均 \(AppFormatters.currency(monthlyCost))")
                .font(.subheadline)
                .foregroundStyle(AppTheme.accentSecondary)

            ForEach(store.subscriptions) { sub in
                subscriptionCard(sub, highlight: false)
            }
        }
    }

    // MARK: - Card

    private func subscriptionCard(_ sub: Subscription, highlight: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "repeat.circle.fill")
                .font(.title2)
                .foregroundStyle(highlight ? AppTheme.accentSecondary : AppTheme.accent)
                .frame(width: 40, height: 40)
                .background((highlight ? AppTheme.accentSecondary : AppTheme.accent).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(sub.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                if !sub.planName.isEmpty {
                    Text(sub.planName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                HStack(spacing: 8) {
                    Text(sub.period.title)
                    Text("·")
                    Text("下次 \(AppFormatters.shortDateTime(sub.nextChargedAt))")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatters.currency(sub.amount))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                if highlight {
                    Text(daysUntil(sub.nextChargedAt))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppTheme.accentSecondary))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
        .contextMenu {
            Button(role: .destructive) {
                store.deleteSubscription(sub)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.mutedInk.opacity(0.5))

            Text("暂无订阅记录")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text("导入订阅续期邮件截图，或点击右上角扫描历史账单自动识别周期性订阅。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                HStack {
                    if isImporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "envelope.open.fill")
                    }
                    Text(isImporting ? "识别中..." : "上传续期邮件截图")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .task(id: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                await importPickedPhoto(item)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    // MARK: - Helpers

    private func daysUntil(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days <= 0 { return "今天" }
        if days == 1 { return "明天" }
        return "\(days) 天后"
    }

    private func importPickedPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            selectedPhoto = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, notePrefix: "订阅续期邮件截图")
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .photoLibrary)
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionListView()
    }
    .environmentObject(LedgerStore())
}
