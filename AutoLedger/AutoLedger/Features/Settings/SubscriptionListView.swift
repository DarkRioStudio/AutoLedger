import AutoLedgerCore
import PhotosUI
import SwiftUI

struct SubscriptionListView: View {
    @EnvironmentObject private var store: LedgerStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImporting = false
    @State private var editingSubscription: Subscription?
    @State private var annualPriceOverrides: [String: Double] = [:]
    @State private var subscriptionNotes: [String: String] = [:]
    private let ocrService = OCRService()
    private let annualPriceKey = "subscriptionAnnualPriceOverrides"
    private let subscriptionNotesKey = "subscriptionNotes"

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
        .sheet(item: $editingSubscription) { subscription in
            SubscriptionEditView(
                subscription: subscription,
                annualPrice: annualPriceOverrides[subscription.id.uuidString],
                note: subscriptionNotes[subscription.id.uuidString] ?? ""
            ) { updated, annualPrice, note in
                store.updateSubscription(updated)
                saveAnnualPrice(annualPrice, for: updated)
                saveNote(note, for: updated)
                store.requestAutomaticBackup()
            }
        }
        .onAppear {
            loadSupplementalSubscriptionData()
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

            annualSummaryCard
        }
    }

    private var annualSummaryCard: some View {
        let annualCost = store.subscriptions.reduce(0.0) { $0 + estimatedAnnualCost(for: $1) }
        let monthlyCost = annualCost / 12.0
        let knownSavings = store.subscriptions.reduce(0.0) { sum, sub in
            guard let suggestion = savingsSuggestion(for: sub) else { return sum }
            return sum + max(0, suggestion.savings)
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("年度总览")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("预估年度订阅开销")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Text(AppFormatters.currency(annualCost))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 10) {
                summaryPill(title: "月均", value: AppFormatters.currency(monthlyCost))
                summaryPill(title: "可优化", value: knownSavings > 0 ? AppFormatters.currency(knownSavings) : "暂无")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.accent.opacity(0.08))
        )
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
        .overlay(alignment: .bottomLeading) {
            if let suggestion = savingsSuggestion(for: sub), suggestion.savings > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                    Text("切换年付可省 \(AppFormatters.currency(suggestion.savings))/年")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
        }
        .padding(18)
        .padding(.bottom, savingsSuggestion(for: sub)?.savings ?? 0 > 0 ? 24 : 0)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
        .contextMenu {
            Button {
                editingSubscription = sub
            } label: {
                Label("编辑", systemImage: "pencil")
            }

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

    private func estimatedAnnualCost(for sub: Subscription) -> Double {
        switch sub.period {
        case .weekly:  return sub.amount * 52.18
        case .monthly: return sub.amount * 12.0
        case .yearly:  return sub.amount
        }
    }

    private func savingsSuggestion(for sub: Subscription) -> (annualPrice: Double, savings: Double)? {
        guard sub.period == .monthly,
              let annualPrice = annualPriceOverrides[sub.id.uuidString],
              annualPrice > 0 else {
            return nil
        }
        return (annualPrice, sub.amount * 12.0 - annualPrice)
    }

    private func loadSupplementalSubscriptionData() {
        annualPriceOverrides = UserDefaults.standard.dictionary(forKey: annualPriceKey) as? [String: Double] ?? [:]
        subscriptionNotes = UserDefaults.standard.dictionary(forKey: subscriptionNotesKey) as? [String: String] ?? [:]
    }

    private func saveAnnualPrice(_ value: Double?, for sub: Subscription) {
        if let value, value > 0 {
            annualPriceOverrides[sub.id.uuidString] = value
        } else {
            annualPriceOverrides.removeValue(forKey: sub.id.uuidString)
        }
        UserDefaults.standard.set(annualPriceOverrides, forKey: annualPriceKey)
    }

    private func saveNote(_ value: String, for sub: Subscription) {
        let note = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty {
            subscriptionNotes.removeValue(forKey: sub.id.uuidString)
        } else {
            subscriptionNotes[sub.id.uuidString] = note
        }
        UserDefaults.standard.set(subscriptionNotes, forKey: subscriptionNotesKey)
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

private struct SubscriptionEditView: View {
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription
    let onSave: (Subscription, Double?, String) -> Void

    @State private var merchant: String
    @State private var planName: String
    @State private var period: SubscriptionPeriod
    @State private var amountText: String
    @State private var lastChargedAt: Date
    @State private var nextChargedAt: Date
    @State private var annualPriceText: String
    @State private var note: String

    init(
        subscription: Subscription,
        annualPrice: Double?,
        note: String,
        onSave: @escaping (Subscription, Double?, String) -> Void
    ) {
        self.subscription = subscription
        self.onSave = onSave
        _merchant = State(initialValue: subscription.merchant)
        _planName = State(initialValue: subscription.planName)
        _period = State(initialValue: subscription.period)
        _amountText = State(initialValue: Self.text(from: subscription.amount))
        _lastChargedAt = State(initialValue: subscription.lastChargedAt)
        _nextChargedAt = State(initialValue: subscription.nextChargedAt)
        _annualPriceText = State(initialValue: annualPrice.map(Self.text(from:)) ?? "")
        _note = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("订阅") {
                    TextField("商户", text: $merchant)
                    TextField("方案名称", text: $planName)
                    Picker("周期", selection: $period) {
                        ForEach(SubscriptionPeriod.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("扣费日期") {
                    DatePicker("最近扣费", selection: $lastChargedAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("下次扣费", selection: $nextChargedAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("费用优化") {
                    TextField("年付价格（可选）", text: $annualPriceText)
                        .keyboardType(.decimalPad)

                    if let savingsText {
                        Text(savingsText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Section("备注") {
                    TextField("备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("编辑订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: period) { _, newValue in
                nextChargedAt = newValue.nextDate(from: lastChargedAt)
            }
            .onChange(of: lastChargedAt) { _, newValue in
                nextChargedAt = period.nextDate(from: newValue)
            }
        }
    }

    private var amount: Double? {
        Self.decimalValue(from: amountText)
    }

    private var annualPrice: Double? {
        Self.decimalValue(from: annualPriceText)
    }

    private var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount != nil
    }

    private var savingsText: String? {
        guard period == .monthly, let amount, let annualPrice, annualPrice > 0 else { return nil }
        let savings = amount * 12.0 - annualPrice
        if savings > 0 {
            return "切换年付可节省 \(AppFormatters.currency(savings))/年"
        }
        return "当前年付价格不低于月付累计。"
    }

    private func save() {
        guard let amount else { return }
        let updated = Subscription(
            id: subscription.id,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            planName: planName.trimmingCharacters(in: .whitespacesAndNewlines),
            period: period,
            amount: amount,
            lastChargedAt: lastChargedAt,
            nextChargedAt: nextChargedAt,
            createdAt: subscription.createdAt
        )
        onSave(updated, annualPrice, note)
        dismiss()
    }

    nonisolated private static func decimalValue(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    nonisolated private static func text(from amount: Double) -> String {
        String(format: "%.2f", amount)
    }
}

#Preview {
    NavigationStack {
        SubscriptionListView()
    }
    .environmentObject(LedgerStore())
}
