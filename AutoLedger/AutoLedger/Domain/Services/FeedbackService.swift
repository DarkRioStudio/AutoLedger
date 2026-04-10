import AutoLedgerCore
import Combine
import MessageUI
import SwiftUI
import UIKit

/// 反馈邮件发送服务 —— 封装 MFMailComposeViewController 调用与降级策略
final class FeedbackService: NSObject, ObservableObject {
    static let shared = FeedbackService()

    static let supportEmail = "support@darkrio326.top"

    @Published var isSending = false
    @Published var sendResult: SendResult?

    enum SendResult: Identifiable {
        case sent, saved, cancelled, failed(String), copiedToClipboard, sharedViaSheet

        var id: String {
            switch self {
            case .sent:               return "sent"
            case .saved:              return "saved"
            case .cancelled:          return "cancelled"
            case .failed(let msg):    return "failed_\(msg)"
            case .copiedToClipboard:  return "copied"
            case .sharedViaSheet:     return "shared"
            }
        }

        var message: String {
            switch self {
            case .sent:              return "反馈已发送，感谢你的帮助！"
            case .saved:             return "邮件已保存为草稿。"
            case .cancelled:         return "已取消发送。"
            case .failed(let msg):   return "发送失败：\(msg)"
            case .copiedToClipboard: return "反馈内容已复制到剪切板，请手动发送至 \(supportEmail)。"
            case .sharedViaSheet:    return "已通过系统分享导出反馈包。"
            }
        }
    }

    var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    /// 通过邮件发送反馈（MFMailComposeViewController）
    func sendViaEmail(
        subject: String,
        body: String,
        zipData: Data,
        zipFileName: String,
        from presenter: UIViewController
    ) {
        guard canSendMail else { return }
        isSending = true
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([Self.supportEmail])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.addAttachmentData(zipData, mimeType: "application/zip", fileName: zipFileName)
        presenter.present(composer, animated: true)
    }

    /// 降级方案 1：复制到剪切板
    func copyToClipboard(subject: String, body: String) {
        UIPasteboard.general.string = "Subject: \(subject)\n\n\(body)"
        sendResult = .copiedToClipboard
    }

    /// 降级方案 2：系统分享 zip 文件
    func shareViaSheet(zipURL: URL, from presenter: UIViewController) {
        let controller = UIActivityViewController(activityItems: [zipURL], applicationActivities: nil)
        presenter.present(controller, animated: true) { [weak self] in
            self?.sendResult = .sharedViaSheet
        }
    }
}

extension FeedbackService: @preconcurrency MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true) { [weak self] in
            self?.isSending = false
            switch result {
            case .sent:      self?.sendResult = .sent
            case .saved:     self?.sendResult = .saved
            case .cancelled: self?.sendResult = .cancelled
            case .failed:    self?.sendResult = .failed(error?.localizedDescription ?? "未知错误")
            @unknown default: self?.sendResult = .failed("未知状态")
            }
        }
    }
}

/// SwiftUI helper: wraps UIViewController presentation
struct MailPresenter: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
