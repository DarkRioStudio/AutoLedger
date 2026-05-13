//
//  ContentView.swift
//  AutoLedgerWatch Watch App
//
//  Created by 张津铖 on 2026/5/13.
//

import SwiftUI

struct ContentView: View {

    @Environment(WatchLedgerViewModel.self) private var viewModel

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
                    }
                }
            }
            .navigationTitle("账本")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isQuickAddPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                viewModel.refreshTransactions()
            }
        }
        .sheet(isPresented: $vm.isQuickAddPresented) {
            QuickAddView()
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.lastFeedback)
    }
}

#Preview {
    ContentView()
}
