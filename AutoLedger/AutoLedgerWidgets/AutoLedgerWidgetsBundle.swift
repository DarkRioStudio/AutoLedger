//
//  AutoLedgerWidgetsBundle.swift
//  AutoLedgerWidgets
//
//  Created by 张津铖 on 2026/4/23.
//

import WidgetKit
import SwiftUI

@main
struct AutoLedgerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyExpenseWidget()
        MonthlyReportWidget()
    }
}
