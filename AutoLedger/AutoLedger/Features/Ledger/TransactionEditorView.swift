import AutoLedgerCore
import SwiftUI
import UIKit

struct TransactionEditorView: View {
    let transaction: Transaction
    let onSave: (Transaction, Bool, Bool) -> Bool
    /// `true` 表示新增模式，导航栏标题显示"新增账单"；`false` 为编辑模式
    var isNew: Bool = false
    var usesNavigationStack = true
    var showsCancelButton = true
    var dismissesOnSave = true
    var onCancel: (() -> Void)?
    var onDuplicate: ((Transaction) -> Void)?
    var onMove: ((Transaction) -> Void)?
    var onDelete: ((Transaction) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: LedgerStore
    @State private var merchant: String
    @State private var amountText: String
    @State private var category: String
    @State private var source: String
    @State private var occurredAt: Date
    @State private var note: String
    @State private var pendingSave: Transaction?
    @State private var pendingRefreshSameMerchantCategory = false
    @State private var showCategoryRefreshPrompt = false
    @State private var showMerchantAliasPrompt = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var subscriptionDraft: Subscription?
    @State private var subscriptionCreatedMessage: String?
    @FocusState private var focusedField: EditorField?

    private enum EditorField: Hashable {
        case amount
        case note
    }

    init(
        transaction: Transaction,
        isNew: Bool = false,
        usesNavigationStack: Bool = true,
        showsCancelButton: Bool = true,
        dismissesOnSave: Bool = true,
        onCancel: (() -> Void)? = nil,
        onDuplicate: ((Transaction) -> Void)? = nil,
        onMove: ((Transaction) -> Void)? = nil,
        onDelete: ((Transaction) -> Void)? = nil,
        onSave: @escaping (Transaction, Bool, Bool) -> Bool
    ) {
        self.transaction = transaction
        self.isNew = isNew
        self.usesNavigationStack = usesNavigationStack
        self.showsCancelButton = showsCancelButton
        self.dismissesOnSave = dismissesOnSave
        self.onCancel = onCancel
        self.onDuplicate = onDuplicate
        self.onMove = onMove
        self.onDelete = onDelete
        self.onSave = onSave
        _merchant = State(initialValue: transaction.merchant)
        _amountText = State(initialValue: isNew ? "" : String(format: "%.2f", transaction.amount))
        _category = State(initialValue: transaction.category)
        _source = State(initialValue: transaction.source)
        _occurredAt = State(initialValue: transaction.occurredAt)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        if usesNavigationStack {
            NavigationStack {
                editorContent
            }
        } else {
            editorContent
        }
    }

    private var editorContent: some View {
        Form {
                Section("transaction_editor.section.basic") {
                    CompositionSafeTextField(
                        placeholder: String(localized: "transaction_editor.merchant"),
                        text: $merchant
                    )

                    Picker("transaction_editor.source", selection: $source) {
                        ForEach(ReceiptSource.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                        if !store.customSources.isEmpty {
                            ForEach(store.customSources, id: \.self) { custom in
                                Text(custom).tag(custom)
                            }
                        }
                    }

                    DatePicker("transaction_editor.date", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("transaction_editor.section.amount") {
                    TextField("transaction_editor.amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)

                    Picker("transaction_editor.category", selection: $category) {
                        ForEach(TransactionCategory.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                        if !store.customCategories.isEmpty {
                            ForEach(store.customCategories, id: \.self) { custom in
                                Text(custom).tag(custom)
                            }
                        }
                    }

                    TextField("transaction_editor.note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .focused($focusedField, equals: .note)
                }

                if !isNew {
                    Section("transaction_subscription.section.title") {
                        Text("transaction_subscription.section.description")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.mutedInk)

                        Button {
                            subscriptionDraft = Subscription.draft(from: editedTransaction())
                        } label: {
                            Label("transaction_subscription.create", systemImage: "calendar.badge.plus")
                        }
                        .disabled(parsedAmount <= 0 || merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityHint(Text("transaction_subscription.create_help"))
                    }
                }
            }
            .autoLedgerFormChrome()
            .navigationTitle(isNew ? String(localized: "transaction_editor.title.new") : String(localized: "transaction_editor.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCancelButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") {
                            if let onCancel {
                                onCancel()
                            } else {
                                dismiss()
                            }
                        }
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        prepareSave()
                    } label: {
                        Label("common.save", systemImage: "checkmark")
                    }
                    .accessibilityLabel(Text("common.save"))
                    .disabled(isSaving || parsedAmount <= 0 || merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if showsTransactionActionMenu {
                        transactionActionMenu
                    }
                }
            }
            .alert("transaction_editor.category_refresh.title", isPresented: $showCategoryRefreshPrompt, presenting: pendingSave) { updated in
                Button("transaction_editor.category_refresh.current_only", role: .cancel) {
                    continueSave(updated, refreshSameMerchantCategory: false)
                }
                Button("transaction_editor.category_refresh.refresh_all") {
                    continueSave(updated, refreshSameMerchantCategory: true)
                }
            } message: { updated in
                Text(String(format: String(localized: "transaction_editor.category_refresh.message_format"), updated.merchant, updated.categoryTitle))
            }
            .alert("transaction_editor.merchant_alias.title", isPresented: $showMerchantAliasPrompt, presenting: pendingSave) { updated in
                Button("transaction_editor.merchant_alias.skip", role: .cancel) {
                    save(
                        updated,
                        refreshSameMerchantCategory: pendingRefreshSameMerchantCategory,
                        saveMerchantAlias: false
                    )
                }
                Button("transaction_editor.merchant_alias.save") {
                    save(
                        updated,
                        refreshSameMerchantCategory: pendingRefreshSameMerchantCategory,
                        saveMerchantAlias: true
                    )
                }
            } message: { updated in
                Text(String(format: String(localized: "transaction_editor.merchant_alias.message_format"), transaction.merchant, updated.merchant))
            }
            .alert("transaction_editor.save_failed.title", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("common.done", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? String(localized: "transaction_editor.save_failed.message"))
            }
            .sheet(item: $subscriptionDraft) { draft in
                TransactionSubscriptionCreateView(
                    subscription: draft,
                    existingSubscription: existingSubscription(matching: draft)
                ) { subscription in
                    store.createSubscription(subscription)
                    subscriptionCreatedMessage = String(
                        format: String(localized: "transaction_subscription.created.message_format"),
                        subscription.merchant,
                        AppFormatters.currency(subscription.amount)
                    )
                }
            }
            .alert("transaction_subscription.created.title", isPresented: Binding(
                get: { subscriptionCreatedMessage != nil },
                set: { if !$0 { subscriptionCreatedMessage = nil } }
            )) {
                Button("common.done", role: .cancel) {}
            } message: {
                Text(subscriptionCreatedMessage ?? "")
            }
    }

    private var showsTransactionActionMenu: Bool {
        !isNew && (onDuplicate != nil || onMove != nil || onDelete != nil)
    }

    private var transactionActionMenu: some View {
        Menu {
            if let onDuplicate {
                Button {
                    onDuplicate(transaction)
                } label: {
                    Label("ledger.action.copy", systemImage: "doc.on.doc")
                }
            }

            if let onMove {
                Button {
                    onMove(transaction)
                } label: {
                    Label("ledger.action.move", systemImage: "folder")
                }
            }

            if let onDelete {
                if onDuplicate != nil || onMove != nil {
                    Divider()
                }

                Button(role: .destructive) {
                    onDelete(transaction)
                    dismiss()
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Text("common.more_actions"))
    }

    private var parsedAmount: Double {
        LedgerAmountInputParser.parse(amountText) ?? 0
    }

    private func editedTransaction() -> Transaction {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return Transaction(
            id: transaction.id,
            merchant: trimmedMerchant.isEmpty ? transaction.merchant : trimmedMerchant,
            amount: parsedAmount,
            occurredAt: occurredAt,
            categoryLabel: category,
            sourceLabel: source,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func shouldPromptCategoryRefresh(for updated: Transaction) -> Bool {
        !isNew && transaction.category != updated.category
    }

    private func shouldPromptMerchantAlias(for updated: Transaction) -> Bool {
        !isNew && store.shouldOfferMerchantAlias(from: transaction, to: updated)
    }

    private func existingSubscription(matching draft: Subscription) -> Subscription? {
        store.subscriptions.first {
            $0.merchant == draft.merchant &&
            $0.period == draft.period &&
            $0.status != .canceled
        }
    }

    private func beginSave(_ updated: Transaction) {
        if shouldPromptCategoryRefresh(for: updated) {
            pendingSave = updated
            showCategoryRefreshPrompt = true
        } else {
            continueSave(updated, refreshSameMerchantCategory: false)
        }
    }

    private func prepareSave() {
        guard !isSaving else { return }
        isSaving = true
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task { @MainActor in
            await Task.yield()
            beginSave(editedTransaction())
        }
    }

    private func continueSave(_ updated: Transaction, refreshSameMerchantCategory: Bool) {
        if shouldPromptMerchantAlias(for: updated) {
            pendingSave = updated
            pendingRefreshSameMerchantCategory = refreshSameMerchantCategory
            showMerchantAliasPrompt = true
        } else {
            save(updated, refreshSameMerchantCategory: refreshSameMerchantCategory, saveMerchantAlias: false)
        }
    }

    private func save(_ updated: Transaction, refreshSameMerchantCategory: Bool, saveMerchantAlias: Bool) {
        let didSave = onSave(updated, refreshSameMerchantCategory, saveMerchantAlias)
        if didSave {
            pendingSave = nil
            pendingRefreshSameMerchantCategory = false
            if dismissesOnSave {
                dismiss()
            } else {
                isSaving = false
            }
        } else {
            isSaving = false
            saveErrorMessage = String(localized: "transaction_editor.save_failed.message")
        }
    }
}

private struct CompositionSafeTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = $text
        guard !context.coordinator.isEditing, uiView.text != text else { return }
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isEditing = false

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textDidChange(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isEditing = false
            let fieldText = textField.text ?? ""
            if fieldText.count < text.wrappedValue.count {
                textField.text = text.wrappedValue
            } else {
                text.wrappedValue = fieldText
            }
        }
    }
}

private struct TransactionSubscriptionCreateView: View {
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription
    let existingSubscription: Subscription?
    let onSave: (Subscription) -> Void

    @State private var merchant: String
    @State private var planName: String
    @State private var period: SubscriptionPeriod
    @State private var amountText: String
    @State private var lastChargedAt: Date
    @State private var nextChargedAt: Date

    init(
        subscription: Subscription,
        existingSubscription: Subscription?,
        onSave: @escaping (Subscription) -> Void
    ) {
        self.subscription = subscription
        self.existingSubscription = existingSubscription
        self.onSave = onSave
        _merchant = State(initialValue: subscription.merchant)
        _planName = State(initialValue: subscription.planName)
        _period = State(initialValue: subscription.period)
        _amountText = State(initialValue: String(format: "%.2f", subscription.amount))
        _lastChargedAt = State(initialValue: subscription.lastChargedAt)
        _nextChargedAt = State(initialValue: subscription.nextChargedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("transaction_subscription.confirm.description")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)

                    if let existingSubscription {
                        Text(
                            String(
                                format: String(localized: "transaction_subscription.existing.message_format"),
                                existingSubscription.merchant,
                                existingSubscription.period.title
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    }
                }

                Section("subscriptions.edit.section.subscription") {
                    TextField("transaction_editor.merchant", text: $merchant)
                    TextField("subscriptions.edit.plan_name", text: $planName)
                    Picker("subscriptions.edit.period", selection: $period) {
                        ForEach(SubscriptionPeriod.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    TextField("transaction_editor.amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("subscriptions.edit.section.charge_dates") {
                    DatePicker("subscriptions.edit.last_charged", selection: $lastChargedAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("subscriptions.edit.next_charge", selection: $nextChargedAt, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .autoLedgerFormChrome()
            .navigationTitle("transaction_subscription.create.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
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
        LedgerAmountInputParser.parse(amountText)
    }

    private var canSave: Bool {
        guard let amount else { return false }
        return !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
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
            status: .active,
            createdAt: subscription.createdAt
        )
        onSave(updated)
        dismiss()
    }
}
