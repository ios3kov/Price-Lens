import CoreGraphics
import Foundation

struct ScannedText: Identifiable, Equatable {
    let id: UUID
    let transcript: String
    let bounds: CGRect
    let confidence: Float
}

enum QuantityDimension: String, Equatable {
    case mass
    case volume
    case count

    var unitLabel: String {
        switch self {
        case .mass: return "kg"
        case .volume: return "L"
        case .count: return "item"
        }
    }
}

struct ProductCandidate: Identifiable, Equatable {
    let id: UUID
    let price: Decimal
    let currencyToken: String?
    /// Quantity normalized to kg, L or item depending on dimension.
    let normalizedQuantity: Decimal
    let dimension: QuantityDimension
    let sourceBounds: CGRect
    let confidence: Float
    let rawText: String

    var unitPrice: Decimal {
        guard normalizedQuantity > 0 else { return 0 }
        return price / normalizedQuantity
    }

    var semanticSignature: String {
        [
            NSDecimalNumber(decimal: price).stringValue,
            NSDecimalNumber(decimal: normalizedQuantity).stringValue,
            dimension.rawValue,
            currencyToken ?? "-"
        ].joined(separator: ":")
    }

    var centerX: CGFloat {
        sourceBounds.midX
    }
}


enum CandidateOrdering {
    static func ordered(_ candidates: [ProductCandidate]) -> [ProductCandidate] {
        guard candidates.count >= 2 else {
            return candidates
        }

        let first = candidates[0]
        let second = candidates[1]

        let dx = abs(first.sourceBounds.midX - second.sourceBounds.midX)
        let dy = abs(first.sourceBounds.midY - second.sourceBounds.midY)

        if dx >= dy {
            return candidates.sorted {
                $0.sourceBounds.midX < $1.sourceBounds.midX
            }
        }

        return candidates.sorted {
            $0.sourceBounds.midY < $1.sourceBounds.midY
        }
    }
}

enum ComparisonFailure: Equatable {
    case incompatibleDimensions
    case differentCurrencies

    var message: String {
        switch self {
        case .incompatibleDimensions:
            return "These products use different units"
        case .differentCurrencies:
            return "These prices use different currencies"
        }
    }
}

enum WinnerSide: Equatable {
    case left
    case right
    case equal
}

struct PriceComparison: Equatable {
    let left: ProductCandidate
    let right: ProductCandidate
    let winner: WinnerSide
    let cheaperPercent: Decimal

    var unitLabel: String {
        left.dimension.unitLabel
    }

    var headline: String {
        switch winner {
        case .left:
            return "A is \(roundedPercent)% cheaper per \(unitLabel)"
        case .right:
            return "B is \(roundedPercent)% cheaper per \(unitLabel)"
        case .equal:
            return "Same price per \(unitLabel)"
        }
    }

    var roundedPercent: Int {
        Int(NSDecimalNumber(decimal: cheaperPercent).doubleValue.rounded())
    }

    var currencyToken: String? {
        left.currencyToken ?? right.currencyToken
    }

    func formattedUnitPrice(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        let amount = String(format: "%.2f", number)
        guard let currencyToken, !currencyToken.isEmpty else {
            return amount
        }

        if ["€", "$", "£"].contains(currencyToken) {
            return "\(currencyToken)\(amount)"
        }
        return "\(amount) \(currencyToken)"
    }
}

enum ScanState: Equatable {
    case searching
    case oneTagFound
    case comparing
    case result(PriceComparison)
    case incompatible(String)
}

enum CameraState: Equatable {
    case preparing
    case ready
    case denied
    case unsupported
    case failed(String)
}
