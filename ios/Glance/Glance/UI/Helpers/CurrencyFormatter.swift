import Foundation

struct CurrencyFormatter {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // Or use Locale.current.currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func format(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? "$?.??"
    }
}
