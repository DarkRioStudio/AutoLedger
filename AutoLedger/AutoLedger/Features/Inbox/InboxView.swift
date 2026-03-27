import PhotosUI
import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var lastRecognizedText = ""

    private let ocrService = OCRService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero

                    liveImportCard

                    if let summary = store.lastImportSummary {
                        statusBanner(summary)
                    }

                    if !lastRecognizedText.isEmpty {
                        recognizedTextCard
                    }

                    Text("示例导入")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    ForEach(store.sampleReceipts) { sample in
                        sampleCard(sample)
                    }

                    if !store.recentImports.isEmpty {
                        Text("最近解析")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        ForEach(store.recentImports.prefix(3)) { receipt in
                            importedCard(receipt)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("AutoLedger")
            .task(id: selectedPhoto) {
                guard let selectedPhoto else {
                    return
                }
                await importPickedPhoto(selectedPhoto)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("把支付截图先跑通，再逐轮接上 OCR 与持久化。")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("当前这轮先交付一个可运行 MVP 壳层：样例导入、规则解析、账本列表和月度总览都能在本地串起来。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))

            HStack(spacing: 12) {
                MetricCard(
                    title: "本月支出",
                    value: AppFormatters.currency(store.monthlySnapshot.totalExpense),
                    detail: "\(store.monthlySnapshot.transactionCount) 笔账单",
                    accent: AppTheme.accent
                )

                MetricCard(
                    title: "Top 商户",
                    value: store.monthlySnapshot.topMerchant,
                    detail: "当前样例账本",
                    accent: AppTheme.accentSecondary
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.heroGradient)
        )
    }

    private func sampleCard(_ sample: SampleReceipt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sample.source.shortTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(sampleBadgeColor(sample.source).opacity(0.14))
                    .foregroundStyle(sampleBadgeColor(sample.source))
                    .clipShape(Capsule())

                Spacer()

                Button("导入示例") {
                    store.importSample(sample)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }

            Text(sample.title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(sample.preview)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)

            Text(sample.rawText)
                .font(.footnote.monospaced())
                .foregroundStyle(AppTheme.ink.opacity(0.82))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var liveImportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("真实截图导入")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("使用系统相册选择支付截图，走 Vision OCR 后直接进入现有解析器和账本。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                HStack {
                    if isImportingPhoto {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "viewfinder")
                    }

                    Text(isImportingPhoto ? "识别中..." : "选择支付截图")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            Text("提示：当前仍保留样例导入，方便在 OCR 失败时继续验证主路径。")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func importedCard(_ receipt: ImportedReceipt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(receipt.merchant)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                Text(AppFormatters.currency(receipt.amount))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            HStack(spacing: 10) {
                Label(receipt.source.title, systemImage: "camera.metering.center.weighted")
                Label(receipt.suggestedCategory.title, systemImage: receipt.suggestedCategory.iconName)
                Text(AppFormatters.shortDateTime(receipt.occurredAt))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.mutedInk)

            Text(receipt.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func statusBanner(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppTheme.accent)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private var recognizedTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近 OCR 文本")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(lastRecognizedText)
                .font(.footnote.monospaced())
                .foregroundStyle(AppTheme.ink.opacity(0.82))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func importPickedPhoto(_ item: PhotosPickerItem) async {
        isImportingPhoto = true
        defer {
            isImportingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw OCRServiceError.loadFailed
            }
            let text = try ocrService.recognizeText(from: data)
            lastRecognizedText = text
            store.importRecognizedText(text)
        } catch {
            store.setImportError(error.localizedDescription)
        }
    }

    private func sampleBadgeColor(_ source: ReceiptSource) -> Color {
        switch source {
        case .wechat:
            return Color(red: 0.18, green: 0.67, blue: 0.36)
        case .alipay:
            return Color(red: 0.07, green: 0.47, blue: 0.87)
        case .appStore:
            return Color(red: 0.34, green: 0.36, blue: 0.82)
        case .manual:
            return AppTheme.accentSecondary
        }
    }
}

#Preview {
    InboxView()
        .environmentObject(LedgerStore())
}
