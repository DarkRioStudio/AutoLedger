import AutoLedgerCore
import PhotosUI
import SwiftUI
import UIKit

struct InboxView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var isImportingClipboard = false
    @State private var showCamera = false
    @State private var capturedImageData: Data?
    @State private var isImportingCamera = false
    @State private var showMerchantSheet = false

    private let ocrService = OCRService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero

                    quickSetupCard

                    liveImportCard

                    if let summary = store.lastImportSummary {
                        statusBanner(summary)
                    }

                    if !store.lastRecognizedText.isEmpty {
                        recognizedTextCard
                    }

                    if !store.recentImports.isEmpty {
                        Text("最近解析")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        ForEach(store.recentImports.prefix(10)) { receipt in
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
            .sheet(isPresented: $showMerchantSheet) {
                merchantSheet
            }
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
            Text("随手记账，一拍即入")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                MetricCard(
                    title: "本月支出",
                    value: AppFormatters.currency(store.monthlySnapshot.totalExpense),
                    detail: "\(store.monthlySnapshot.transactionCount) 笔账单",
                    accent: AppTheme.accent
                )
                .onTapGesture { selectedTab = 2 }

                MetricCard(
                    title: "Top 商户",
                    value: store.monthlySnapshot.topMerchant,
                    detail: "\(store.monthlySnapshot.topMerchants.count) 家商户",
                    accent: AppTheme.accentSecondary
                )
                .onTapGesture { showMerchantSheet = true }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.heroGradient)
        )
    }

    private var quickSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("一键记账")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("将快捷指令绑定到操作按钮，长按一下即可截图记账。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                setupStep(
                    number: "1",
                    title: "获取快捷指令",
                    detail: "点击下方按钮添加「一键记账」快捷指令到你的 iPhone。"
                )

                Link(destination: URL(string: "https://www.icloud.com/shortcuts/e64528fb5bc34afdab4d7c64242d537e")!) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("添加快捷指令")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentSecondary)

                setupStep(
                    number: "2",
                    title: "绑定操作按钮",
                    detail: "前往「设置  →  操作按钮  →  快捷指令」，选择刚才添加的「一键记账」。"
                )

                Button {
                    if let url = URL(string: "App-prefs:") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("打开系统设置")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent.opacity(0.85))

                setupStep(
                    number: "3",
                    title: "长按操作按钮即可记账",
                    detail: "截图支付页面后长按操作按钮，自动识别并记入账本。"
                )
            }

            Text("仅支持 iPhone 15 Pro 及以上带操作按钮的机型。")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)

            Text("你也可以复制支付截图后回到 App，自动读取剪切板记账（需在设置中开启）。")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func setupStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppTheme.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
    }

    private var liveImportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("支付账单导入")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text("选择支付截图或拍照，自动识别金额和商户并记入账本。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Image(systemName: "doc.text.viewfinder")
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
                        Image(systemName: "photo.on.rectangle")
                    }

                    Text(isImportingPhoto ? "识别中..." : "从相册选取")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        if isImportingCamera {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                        }

                        Text(isImportingCamera ? "识别中..." : "拍照识别")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent.opacity(0.85))
            }

            Button {
                Task { await importFromClipboard() }
            } label: {
                HStack {
                    if isImportingClipboard {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.on.clipboard")
                    }

                    Text(isImportingClipboard ? "识别中..." : "从剪切板粘贴")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentSecondary)

            Text("支持微信/支付宝等支付截图，可从相册选取、拍照或直接粘贴。")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.card)
        )
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: $capturedImageData)
        }
        .task(id: capturedImageData) {
            guard let data = capturedImageData else { return }
            capturedImageData = nil
            await importCapturedPhoto(data)
        }
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

            Text(store.lastRecognizedText)
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
        store.prepareForLiveImport()
        defer {
            isImportingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw OCRServiceError.loadFailed
            }
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .photoLibrary)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .photoLibrary)
        }
    }

    private func importCapturedPhoto(_ data: Data) async {
        isImportingCamera = true
        store.prepareForLiveImport()
        defer { isImportingCamera = false }

        do {
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .camera)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .camera)
        }
    }

    private var merchantRankings: [(merchant: String, total: Double)] {
        var totals: [String: Double] = [:]
        for t in store.transactions {
            totals[t.merchant, default: 0] += t.amount
        }
        return totals.map { (merchant: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    @ViewBuilder
    private var merchantSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(merchantRankings.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .frame(width: 24)

                        Text(item.merchant)
                            .font(.body)
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Text(AppFormatters.currency(item.total))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .listRowBackground(AppTheme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("商户消费排名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { showMerchantSheet = false }
                }
            }
        }
    }

    private func importFromClipboard() async {
        isImportingClipboard = true
        store.prepareForLiveImport()
        defer { isImportingClipboard = false }

        guard let image = UIPasteboard.general.image,
              let data = image.pngData() else {
            store.setImportError("剪切板中没有图片。", imageSource: .clipboard)
            return
        }

        do {
            let text = try ocrService.recognizeText(from: data)
            store.importRecognizedText(text, imageSource: .clipboard)
        } catch {
            store.setImportError(error.localizedDescription, imageSource: .clipboard)
        }
    }
}

#Preview {
    InboxView(selectedTab: .constant(0))
        .environmentObject(LedgerStore())
}
