import AutoLedgerCore
import PhotosUI
import SwiftUI
import UIKit

#if canImport(VisionKit) && !targetEnvironment(macCatalyst)
import VisionKit
#endif

struct LiveReceiptScannerView: View {
    let isCameraPhotoAvailable: Bool
    let onRecognizedText: (String) -> Void
    let onFallbackImageData: (Data, ImageSource) async -> Void
    let onRequestCameraPhoto: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var availability: LiveReceiptScannerAvailability = .unavailable(.unsupported)
    @State private var latestText = ""
    @State private var stableText = ""
    @State private var scannerMessage: String?
    @State private var selectedFallbackPhoto: PhotosPickerItem?
    @State private var isImportingFallbackPhoto = false

    private var canConfirmLiveText: Bool {
        !stableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                scannerSurface

                VStack(spacing: 14) {
                    statusCard
                    Spacer(minLength: 0)
                    previewCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 22)
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("live_receipt_scan.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                availability = LiveReceiptScannerCapability.currentAvailability()
            }
            .task(id: latestText) {
                await stabilizeLatestText()
            }
            .task(id: selectedFallbackPhoto) {
                guard let selectedFallbackPhoto else { return }
                await importFallbackPhoto(selectedFallbackPhoto)
            }
        }
    }

    @ViewBuilder
    private var scannerSurface: some View {
        switch availability {
        case .available(let languages):
            liveScanner(languages: languages)
        case .unavailable:
            fallbackSurface
        }
    }

    @ViewBuilder
    private func liveScanner(languages: [String]) -> some View {
        #if canImport(VisionKit) && !targetEnvironment(macCatalyst)
        if #available(iOS 16.0, *) {
            LiveTextDataScannerRepresentable(
                recognitionLanguages: languages,
                onTextChanged: { text in
                    latestText = text
                    scannerMessage = nil
                },
                onUnavailable: { reason in
                    availability = .unavailable(reason)
                    scannerMessage = reason.localizedMessage
                }
            )
            .ignoresSafeArea()
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.40),
                        Color.clear,
                        Color.black.opacity(0.52)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        } else {
            fallbackSurface
        }
        #else
        fallbackSurface
        #endif
    }

    private var fallbackSurface: some View {
        AppTheme.screenGradient
            .ignoresSafeArea()
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIconName)
                .font(.headline.weight(.bold))
                .foregroundStyle(statusColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(statusColor.opacity(0.16)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .autoLedgerCardSurface(cornerRadius: 20)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("live_receipt_scan.preview.title", systemImage: "text.viewfinder")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Spacer()

                if !recognizedPreviewText.isEmpty {
                    Text(String(format: String(localized: "live_receipt_scan.lines_format"), recognizedPreviewLineCount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Text(recognizedPreviewText.isEmpty ? String(localized: "live_receipt_scan.preview.empty") : recognizedPreviewText)
                .font(.footnote.monospaced())
                .foregroundStyle(recognizedPreviewText.isEmpty ? AppTheme.mutedInk : AppTheme.ink.opacity(0.86))
                .lineLimit(8)
                .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                )

            if let scannerMessage {
                Text(scannerMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            HStack(spacing: 10) {
                if isCameraPhotoAvailable {
                    Button {
                        dismiss()
                        onRequestCameraPhoto()
                    } label: {
                        Label("live_receipt_scan.fallback.camera", systemImage: "camera.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }

                PhotosPicker(
                    selection: $selectedFallbackPhoto,
                    matching: .images,
                    preferredItemEncoding: .automatic
                ) {
                    Label("live_receipt_scan.fallback.photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
                .disabled(isImportingFallbackPhoto)

                Spacer(minLength: 0)

                Button {
                    confirmLiveText()
                } label: {
                    if isImportingFallbackPhoto {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("live_receipt_scan.confirm", systemImage: "checkmark.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!canConfirmLiveText || isImportingFallbackPhoto)
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(16)
        .autoLedgerCardSurface(cornerRadius: 22)
    }

    private var statusIconName: String {
        switch availability {
        case .available:
            canConfirmLiveText ? "checkmark.seal.fill" : "viewfinder.circle.fill"
        case .unavailable:
            "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch availability {
        case .available:
            canConfirmLiveText ? AppTheme.accent : AppTheme.accentSecondary
        case .unavailable:
            .orange
        }
    }

    private var statusTitle: LocalizedStringKey {
        switch availability {
        case .available:
            canConfirmLiveText ? "live_receipt_scan.status.detected" : "live_receipt_scan.status.scanning"
        case .unavailable:
            "live_receipt_scan.status.unavailable"
        }
    }

    private var statusDetail: LocalizedStringKey {
        switch availability {
        case .available:
            canConfirmLiveText ? "live_receipt_scan.status.detected_detail" : "live_receipt_scan.status.scanning_detail"
        case .unavailable(let reason):
            reason.localizedDetailKey
        }
    }

    private var recognizedPreviewText: String {
        stableText.isEmpty ? latestText : stableText
    }

    private var recognizedPreviewLineCount: Int {
        recognizedPreviewText
            .split(whereSeparator: \.isNewline)
            .filter { !String($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    private func stabilizeLatestText() async {
        let candidate = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            stableText = ""
            return
        }

        do {
            try await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            stableText = candidate
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func confirmLiveText() {
        let text = stableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onRecognizedText(text)
        dismiss()
    }

    private func importFallbackPhoto(_ item: PhotosPickerItem) async {
        isImportingFallbackPhoto = true
        defer {
            isImportingFallbackPhoto = false
            selectedFallbackPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw OCRServiceError.loadFailed
            }
            await onFallbackImageData(data, .photoLibrary)
            dismiss()
        } catch {
            scannerMessage = error.localizedDescription
        }
    }
}

private enum LiveReceiptScannerAvailability: Equatable {
    case available(languages: [String])
    case unavailable(LiveReceiptScannerUnavailableReason)
}

private enum LiveReceiptScannerUnavailableReason: Equatable {
    case unsupported
    case cameraRestricted
    case systemUnavailable

    var localizedDetailKey: LocalizedStringKey {
        switch self {
        case .unsupported:
            return "live_receipt_scan.unavailable.unsupported"
        case .cameraRestricted:
            return "live_receipt_scan.unavailable.camera_restricted"
        case .systemUnavailable:
            return "live_receipt_scan.unavailable.system"
        }
    }

    var localizedMessage: String {
        switch self {
        case .unsupported:
            return String(localized: "live_receipt_scan.unavailable.unsupported")
        case .cameraRestricted:
            return String(localized: "live_receipt_scan.unavailable.camera_restricted")
        case .systemUnavailable:
            return String(localized: "live_receipt_scan.unavailable.system")
        }
    }
}

@MainActor
private enum LiveReceiptScannerCapability {
    static func currentAvailability() -> LiveReceiptScannerAvailability {
        #if canImport(VisionKit) && !targetEnvironment(macCatalyst)
        if #available(iOS 16.0, *) {
            guard DataScannerViewController.isSupported else {
                return .unavailable(.unsupported)
            }
            guard DataScannerViewController.isAvailable else {
                return .unavailable(.systemUnavailable)
            }
            return .available(languages: supportedRecognitionLanguages())
        }
        #endif
        return .unavailable(.unsupported)
    }

    #if canImport(VisionKit) && !targetEnvironment(macCatalyst)
    @available(iOS 16.0, *)
    private static func supportedRecognitionLanguages() -> [String] {
        let preferred = LedgerOCRLanguageHintResolver(
            localeIdentifier: Locale.autoupdatingCurrent.identifier,
            languagePackSet: .builtIn
        ).recognitionLanguages
        let supported = Set(DataScannerViewController.supportedTextRecognitionLanguages)
        let filtered = preferred.filter { supported.contains($0) }
        return filtered.isEmpty ? [] : filtered
    }
    #endif
}

#if canImport(VisionKit) && !targetEnvironment(macCatalyst)
@available(iOS 16.0, *)
private struct LiveTextDataScannerRepresentable: UIViewControllerRepresentable {
    let recognitionLanguages: [String]
    let onTextChanged: (String) -> Void
    let onUnavailable: (LiveReceiptScannerUnavailableReason) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: recognitionLanguages)],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.bind(to: scanner)
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        guard !uiViewController.isScanning else { return }
        do {
            try uiViewController.startScanning()
        } catch DataScannerViewController.ScanningUnavailable.cameraRestricted {
            onUnavailable(.cameraRestricted)
        } catch DataScannerViewController.ScanningUnavailable.unsupported {
            onUnavailable(.unsupported)
        } catch {
            onUnavailable(.systemUnavailable)
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        coordinator.stop()
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: LiveTextDataScannerRepresentable
        private var streamTask: Task<Void, Never>?

        init(parent: LiveTextDataScannerRepresentable) {
            self.parent = parent
        }

        func bind(to scanner: DataScannerViewController) {
            streamTask?.cancel()
            streamTask = Task { @MainActor in
                for await items in scanner.recognizedItems {
                    guard !Task.isCancelled else { return }
                    parent.onTextChanged(Self.recognizedText(from: items))
                }
            }
        }

        func stop() {
            streamTask?.cancel()
            streamTask = nil
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            switch error {
            case .cameraRestricted:
                parent.onUnavailable(.cameraRestricted)
            case .unsupported:
                parent.onUnavailable(.unsupported)
            @unknown default:
                parent.onUnavailable(.systemUnavailable)
            }
        }

        private static func recognizedText(from items: [RecognizedItem]) -> String {
            items
                .compactMap { item -> String? in
                    guard case .text(let text) = item else { return nil }
                    let transcript = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    return transcript.isEmpty ? nil : transcript
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
#endif

#Preview {
    LiveReceiptScannerView(
        isCameraPhotoAvailable: true,
        onRecognizedText: { _ in },
        onFallbackImageData: { _, _ in },
        onRequestCameraPhoto: {}
    )
}
