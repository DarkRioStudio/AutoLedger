//
//  ContentView.swift
//  AutoLedgerWatch Watch App
//
//  Created by 张津铖 on 2026/5/13.
//

import SwiftUI

struct ContentView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            TabView(selection: $selectedPage) {
                WatchTodaySummaryPage()
                    .tag(0)

                WatchRecentTransactionsPage()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.isVoiceRecorderPresented = true
                    } label: {
                        Image(systemName: "mic")
                    }
                    .accessibilityLabel(Text("watch.voice_ledger.title"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isQuickAddPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("watch.quick_add.title"))
                }
            }
            .refreshable {
                viewModel.refreshTransactions()
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.pendingCount > 0 {
                    Text(String(format: String(localized: "watch.pending_sync_format"), viewModel.pendingCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
        }
        .sheet(isPresented: $vm.isQuickAddPresented) {
            QuickAddView()
                .environment(viewModel)
        }
        .sheet(isPresented: $vm.isVoiceRecorderPresented) {
            WatchVoiceRecorderView()
                .environment(viewModel)
        }
        .overlay(alignment: .bottom) {
            if let feedback = viewModel.lastFeedback {
                Text(feedback)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .task {
            viewModel.requestInitialSyncIfNeeded()
        }
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.lastFeedback)
    }

    private var navigationTitle: LocalizedStringKey {
        selectedPage == 1 ? "watch.recent.title" : "watch.today.title"
    }
}

private struct WatchTodaySummaryPage: View {
    @Environment(WatchLedgerViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.todaySummary.ledgerName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text("watch.today.title")
                        .font(.headline)

                    Text(viewModel.todaySummary.formattedAmount)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text(String(format: String(localized: "watch.today.count_format"), viewModel.todaySummary.transactionCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let recentDisplayName = viewModel.todaySummary.recentDisplayName {
                        Label(recentDisplayName, systemImage: "clock")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityLabel(
                                Text(String(format: String(localized: "watch.today.latest_format"), recentDisplayName))
                            )
                    } else if viewModel.todaySummary.isEmpty {
                        Text("watch.today.empty.description")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let updatedAt = viewModel.todaySummary.formattedUpdatedAt {
                        Text(String(format: String(localized: "watch.today.updated_format"), updatedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let snapshotStatusText = viewModel.todaySummary.snapshotStatusText {
                        Label(snapshotStatusText, systemImage: "exclamationmark.icloud")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    Text(String(format: String(localized: "watch.today.accessibility_format"), viewModel.todaySummary.formattedAmount, viewModel.todaySummary.transactionCount))
                )

                HStack(spacing: 8) {
                    Button {
                        viewModel.isVoiceRecorderPresented = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel(Text("watch.voice_ledger.title"))

                    Button {
                        viewModel.isQuickAddPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(Text("watch.quick_add.title"))
                }
                .labelStyle(.iconOnly)
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WatchRecentTransactionsPage: View {
    @Environment(WatchLedgerViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("watch.recent.title")
                            .font(.headline)
                        Text(viewModel.todaySummary.ledgerName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if viewModel.recentTransactions.isEmpty {
                    ContentUnavailableView(
                        "watch.empty.title",
                        systemImage: "tray",
                        description: Text("watch.empty.description")
                    )
                    .font(.caption)
                } else {
                    ForEach(viewModel.recentTransactions.prefix(5)) { tx in
                        NavigationLink {
                            WatchTransactionDetailView(tx: tx)
                        } label: {
                            WatchTransactionRow(tx: tx)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WatchTransactionRow: View {
    let tx: WatchTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant)
                    .font(.headline)
                    .lineLimit(1)
                Text(tx.compactDateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Text(tx.formattedAmount)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(String(format: String(localized: "watch.transaction.accessibility_format"), tx.merchant, tx.formattedAmount, tx.compactDateText))
        )
    }
}

private struct WatchTransactionDetailView: View {
    let tx: WatchTransaction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tx.formattedAmount)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text(tx.merchant)
                        .font(.headline)
                        .lineLimit(2)
                }
                .padding(.bottom, 2)

                WatchTransactionDetailRow(
                    title: String(localized: "watch.transaction.category"),
                    value: tx.displayCategory,
                    icon: "tag"
                )
                WatchTransactionDetailRow(
                    title: String(localized: "watch.transaction.source"),
                    value: tx.displaySource,
                    icon: "tray.and.arrow.down"
                )
                WatchTransactionDetailRow(
                    title: String(localized: "watch.transaction.time"),
                    value: tx.formattedDetailDate,
                    icon: "clock"
                )
                WatchTransactionDetailRow(
                    title: String(localized: "watch.transaction.note"),
                    value: tx.displayNote,
                    icon: "note.text"
                )
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("watch.transaction.detail_title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
    }
}

private struct WatchTransactionDetailRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
