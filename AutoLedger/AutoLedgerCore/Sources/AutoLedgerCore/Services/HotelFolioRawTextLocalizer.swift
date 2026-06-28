import Foundation

public struct HotelFolioRawTextLocalizer: Sendable {
    private enum Field: String, CaseIterable {
        case hotelName
        case hotelBrand
        case hotelGroup
        case guestName
        case folioNumber
        case invoiceNumber
        case confirmationNumber
        case checkInDate
        case checkOutDate
        case nights
        case roomNumber
        case roomType
        case roomRate
        case description
        case amount
        case roomCharge
        case tax
        case serviceCharge
        case foodBeverage
        case otherCharges
        case subtotal
        case total
        case paymentMethod
        case balance
        case cashier

        func title(localeIdentifier: String) -> String {
            if localeIdentifier.hasPrefix("zh-hant") || localeIdentifier.hasPrefix("zh_hant") {
                switch self {
                case .hotelName: return "酒店名稱"
                case .hotelBrand: return "品牌"
                case .hotelGroup: return "集團"
                case .guestName: return "住客姓名"
                case .folioNumber: return "水單號"
                case .invoiceNumber: return "發票號"
                case .confirmationNumber: return "訂單號"
                case .checkInDate: return "入住日期"
                case .checkOutDate: return "退房日期"
                case .nights: return "晚數"
                case .roomNumber: return "房號"
                case .roomType: return "房型"
                case .roomRate: return "房價"
                case .description: return "項目"
                case .amount: return "金額"
                case .roomCharge: return "房費"
                case .tax: return "稅費"
                case .serviceCharge: return "服務費"
                case .foodBeverage: return "餐飲"
                case .otherCharges: return "其他費用"
                case .subtotal: return "小計"
                case .total: return "總額"
                case .paymentMethod: return "支付方式"
                case .balance: return "餘額"
                case .cashier: return "收銀員"
                }
            }

            if localeIdentifier.hasPrefix("zh") {
                switch self {
                case .hotelName: return "酒店名称"
                case .hotelBrand: return "品牌"
                case .hotelGroup: return "集团"
                case .guestName: return "住客姓名"
                case .folioNumber: return "水单号"
                case .invoiceNumber: return "发票号"
                case .confirmationNumber: return "订单号"
                case .checkInDate: return "入住日期"
                case .checkOutDate: return "退房日期"
                case .nights: return "晚数"
                case .roomNumber: return "房号"
                case .roomType: return "房型"
                case .roomRate: return "房价"
                case .description: return "项目"
                case .amount: return "金额"
                case .roomCharge: return "房费"
                case .tax: return "税费"
                case .serviceCharge: return "服务费"
                case .foodBeverage: return "餐饮"
                case .otherCharges: return "其他费用"
                case .subtotal: return "小计"
                case .total: return "总额"
                case .paymentMethod: return "支付方式"
                case .balance: return "余额"
                case .cashier: return "收银员"
                }
            }

            if localeIdentifier.hasPrefix("ja") {
                switch self {
                case .hotelName: return "ホテル名"
                case .hotelBrand: return "ブランド"
                case .hotelGroup: return "グループ"
                case .guestName: return "宿泊者名"
                case .folioNumber: return "明細番号"
                case .invoiceNumber: return "請求書番号"
                case .confirmationNumber: return "予約番号"
                case .checkInDate: return "チェックイン日"
                case .checkOutDate: return "チェックアウト日"
                case .nights: return "泊数"
                case .roomNumber: return "部屋番号"
                case .roomType: return "部屋タイプ"
                case .roomRate: return "客室料金"
                case .description: return "項目"
                case .amount: return "金額"
                case .roomCharge: return "宿泊料金"
                case .tax: return "税金"
                case .serviceCharge: return "サービス料"
                case .foodBeverage: return "飲食"
                case .otherCharges: return "その他料金"
                case .subtotal: return "小計"
                case .total: return "合計"
                case .paymentMethod: return "支払い方法"
                case .balance: return "残高"
                case .cashier: return "レジ担当"
                }
            }

            switch self {
            case .hotelName: return "Hotel Name"
            case .hotelBrand: return "Brand"
            case .hotelGroup: return "Group"
            case .guestName: return "Guest Name"
            case .folioNumber: return "Folio No."
            case .invoiceNumber: return "Invoice No."
            case .confirmationNumber: return "Confirmation No."
            case .checkInDate: return "Check-in Date"
            case .checkOutDate: return "Check-out Date"
            case .nights: return "Nights"
            case .roomNumber: return "Room No."
            case .roomType: return "Room Type"
            case .roomRate: return "Room Rate"
            case .description: return "Description"
            case .amount: return "Amount"
            case .roomCharge: return "Room Charge"
            case .tax: return "Tax"
            case .serviceCharge: return "Service Charge"
            case .foodBeverage: return "Food & Beverage"
            case .otherCharges: return "Other Charges"
            case .subtotal: return "Subtotal"
            case .total: return "Total"
            case .paymentMethod: return "Payment Method"
            case .balance: return "Balance"
            case .cashier: return "Cashier"
            }
        }
    }

    private static let labelMap: [String: Field] = {
        var labels: [String: Field] = [:]
        for entry in labelEntries {
            labels[normalizeLabel(entry.label)] = entry.field
        }
        return labels
    }()

    private static let prefixLabelEntries: [(label: String, field: Field)] = labelEntries.sorted {
        $0.label.count > $1.label.count
    }

    private static let labelEntries: [(label: String, field: Field)] = {
        var entries: [(label: String, field: Field)] = []
        func add(_ values: [String], _ field: Field) {
            entries.append(contentsOf: values.map { ($0, field) })
        }

        add(["hotel", "hotel name", "property", "property name", "酒店", "酒店名称", "酒店名稱", "ホテル名"], .hotelName)
        add(["brand", "hotel brand", "品牌", "ブランド"], .hotelBrand)
        add(["group", "hotel group", "集团", "集團", "グループ"], .hotelGroup)
        add(["guest", "guest name", "guest full name", "customer", "name", "住客", "住客姓名", "客人姓名", "宿泊者名"], .guestName)
        add(["folio", "folio no", "folio number", "folio #", "水单号", "水單號", "明細番号"], .folioNumber)
        add(["invoice", "invoice no", "invoice number", "invoice #", "发票号", "發票號", "請求書番号"], .invoiceNumber)
        add(["confirmation", "confirmation no", "confirmation number", "reservation", "reservation no", "booking no", "订单号", "訂單號", "预订号", "預訂號", "予約番号"], .confirmationNumber)
        add(["arrival", "arrival date", "check in", "check-in", "check in date", "check-in date", "入住", "入住日期", "チェックイン"], .checkInDate)
        add(["departure", "departure date", "check out", "check-out", "check out date", "check-out date", "退房", "退房日期", "チェックアウト"], .checkOutDate)
        add(["night", "nights", "no of nights", "晚数", "晚數", "泊数"], .nights)
        add(["room", "room no", "room number", "room #", "房号", "房號", "部屋番号"], .roomNumber)
        add(["room type", "room category", "房型", "部屋タイプ"], .roomType)
        add(["room rate", "rate", "daily rate", "房价", "房價", "客室料金"], .roomRate)
        add(["description", "item", "particulars", "项目", "項目", "摘要"], .description)
        add(["amount", "charge", "金额", "金額"], .amount)
        add(["room charge", "room charges", "room revenue", "accommodation", "房费", "房費", "宿泊料金"], .roomCharge)
        add(["tax", "taxes", "vat", "gst", "税费", "稅費", "税金"], .tax)
        add(["service charge", "service fee", "服务费", "服務費", "サービス料"], .serviceCharge)
        add(["food", "beverage", "food beverage", "f&b", "restaurant", "餐饮", "餐飲", "飲食"], .foodBeverage)
        add(["other", "other charge", "other charges", "misc", "miscellaneous", "其他费用", "其他費用", "その他料金"], .otherCharges)
        add(["subtotal", "sub total", "小计", "小計"], .subtotal)
        add(["total", "grand total", "total amount", "balance due", "总额", "總額", "合计", "合計"], .total)
        add(["payment", "payment method", "paid by", "settlement", "支付方式", "付款方式", "支払い方法"], .paymentMethod)
        add(["balance", "balance amount", "余额", "餘額", "残高"], .balance)
        add(["cashier", "clerk", "收银员", "收銀員", "レジ担当"], .cashier)
        return entries
    }()

    public init() {}

    public func localizedText(_ rawText: String, locale: Locale = .current) -> String {
        let localeIdentifier = locale.identifier.lowercased()
        return rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { localizeLine($0, localeIdentifier: localeIdentifier) }
            .joined(separator: "\n")
    }

    private func localizeLine(_ line: String, localeIdentifier: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return line }

        if let separator = firstSeparator(in: trimmed) {
            let label = String(trimmed[..<separator.lowerBound])
            let value = String(trimmed[separator.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let field = Self.labelMap[Self.normalizeLabel(label)] {
                return "\(field.title(localeIdentifier: localeIdentifier)): \(value)"
            }
        }

        if let prefix = localizedPrefixMatch(in: trimmed, localeIdentifier: localeIdentifier) {
            return prefix
        }

        if let field = Self.labelMap[Self.normalizeLabel(trimmed)] {
            return field.title(localeIdentifier: localeIdentifier)
        }

        return line
    }

    private func firstSeparator(in line: String) -> Range<String.Index>? {
        for separator in [":", "：", "\t"] {
            if let range = line.range(of: separator) {
                return range
            }
        }
        return nil
    }

    private func localizedPrefixMatch(in line: String, localeIdentifier: String) -> String? {
        let lowercased = line.lowercased()
        for entry in Self.prefixLabelEntries {
            let label = entry.label.lowercased()
            if lowercased.hasPrefix(label + " ") {
                let value = String(line.dropFirst(entry.label.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { continue }
                return "\(entry.field.title(localeIdentifier: localeIdentifier)): \(value)"
            }
        }
        return nil
    }

    private static func normalizeLabel(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{3000}", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "号", with: "號")
    }
}
