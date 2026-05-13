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

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            List {
                if viewModel.recentTransactions.isEmpty {
                    ContentUnavailableView(
                        "暂无记录",
                        systemImage: "tray",
                        description: Text("在 iPhone 上记账后同步显示")
                    )
                } else {
                    ForEach(viewModel.recentTransactions) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.merchant)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(tx.formattedDate)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(tx.formattedAmount)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(tx.merchant)，\(tx.formattedAmount)，\(tx.formattedDate)")
                    }
                }
            }
            .navigationTitle("账本")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.isVoiceRecorderPresented = true
                    } label: {
                        Image(systemName: "mic")
                    }
                    .accessibilityLabel("语音记账")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isQuickAddPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("快速记账")
                }
            }
            .refreshable {
                viewModel.refreshTransactions()
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.pendingCount > 0 {
                    Text("\(viewModel.pendingCount) 笔待同步")
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
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.lastFeedback)
    }
}

#Preview {
    ContentView()
}
