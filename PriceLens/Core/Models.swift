import CoreGraphics
import Foundation

struct ScannedText: Identifiable, Equatable {
    let id: UUID
    let transcript: String
    let bounds: CGRect
    let confidence: Float
}


enum ScanRegionLayout {
    static func rect(in bounds: CGRect) -> CGRect? {
        guard bounds.width > 0, bounds.height > 0 else {
            return nil
        }

        return CGRect(
            x: bounds.minX + bounds.width * 0.08,
            y: bounds.minY + bounds.height * 0.28,
            width: bounds.width * 0.84,
            height: bounds.height * 0.32
        )
    }
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




enum ComparisonSessionError: Error, Equatable {
    case duplicate
    case incompatibleDimensions
    case differentCurrencies

    var message: String {
        switch self {
        case .duplicate:
            return "This item is already in the comparison"
        case .incompatibleDimensions:
            return "This item uses a different unit"
        case .differentCurrencies:
            return "This item uses a different currency"
        }
    }
}

struct ComparisonSession: Equatable {
    private(set) var items: [ProductCandidate] = []

    mutating func add(
        _ candidate: ProductCandidate
    ) -> Result<Void, ComparisonSessionError> {
        if items.contains(where: {
            $0.semanticSignature == candidate.semanticSignature
        }) {
            return .failure(.duplicate)
        }

        if let first = items.first {
            guard first.dimension == candidate.dimension else {
                return .failure(.incompatibleDimensions)
            }

            if let firstCurrency = ComparisonEngine.normalizedCurrency(
                first.currencyToken
            ),
               let candidateCurrency = ComparisonEngine.normalizedCurrency(
                candidate.currencyToken
               ),
               firstCurrency != candidateCurrency {
                return .failure(.differentCurrencies)
            }
        }

        items.append(candidate)
        return .success(())
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    mutating func clear() {
        items.removeAll()
    }

    var rankedItems: [ProductCandidate] {
        items.sorted {
            if $0.unitPrice == $1.unitPrice {
                return $0.semanticSignature < $1.semanticSignature
            }
            return $0.unitPrice < $1.unitPrice
        }
    }

    var bestItem: ProductCandidate? {
        rankedItems.first
    }

    func savingsPercent(
        versus candidate: ProductCandidate
    ) -> Decimal? {
        guard let bestItem,
              bestItem.unitPrice > 0,
              candidate.unitPrice > 0 else {
            return nil
        }

        if candidate.semanticSignature == bestItem.semanticSignature {
            return 0
        }

        return (
            (candidate.unitPrice - bestItem.unitPrice)
            / candidate.unitPrice
        ) * 100
    }

    func compatibility(
        with candidate: ProductCandidate
    ) -> Result<Void, ComparisonSessionError> {
        guard let first = items.first else {
            return .success(())
        }

        guard first.dimension == candidate.dimension else {
            return .failure(.incompatibleDimensions)
        }

        if let firstCurrency = ComparisonEngine.normalizedCurrency(
            first.currencyToken
        ),
           let candidateCurrency = ComparisonEngine.normalizedCurrency(
            candidate.currencyToken
           ),
           firstCurrency != candidateCurrency {
            return .failure(.differentCurrencies)
        }

        if items.contains(where: {
            $0.semanticSignature == candidate.semanticSignature
        }) {
            return .failure(.duplicate)
        }

        return .success(())
    }
}


enum CandidatePairSelection: Equatable {
    case none
    case one(ProductCandidate)
    case pair(ProductCandidate, ProductCandidate)
    case tooMany
}

enum CandidatePairSelector {
    static func select(
        from candidates: [ProductCandidate]
    ) -> CandidatePairSelection {
        let deduplicated = CandidateDeduplicator.deduplicated(candidates)

        switch deduplicated.count {
        case 0:
            return .none
        case 1:
            return .one(deduplicated[0])
        case 2:
            let ordered = CandidateOrdering.ordered(deduplicated)
            return .pair(ordered[0], ordered[1])
        default:
            return .tooMany
        }
    }
}

enum CandidateDeduplicator {
    static func deduplicated(
        _ candidates: [ProductCandidate],
        centerTolerance: CGFloat = 48
    ) -> [ProductCandidate] {
        var output: [ProductCandidate] = []

        for candidate in candidates.sorted(by: { $0.confidence > $1.confidence }) {
            let isDuplicate = output.contains { existing in
                guard existing.semanticSignature == candidate.semanticSignature else {
                    return false
                }

                let dx = abs(
                    existing.sourceBounds.midX - candidate.sourceBounds.midX
                )
                let dy = abs(
                    existing.sourceBounds.midY - candidate.sourceBounds.midY
                )

                return dx < centerTolerance && dy < centerTolerance
            }

            if !isDuplicate {
                output.append(candidate)
            }
        }

        return output
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



struct DropoutGraceGate {
    private(set) var generation = 0
    private(set) var isPending = false

    mutating func begin() -> Int? {
        guard !isPending else {
            return nil
        }

        generation += 1
        isPending = true
        return generation
    }

    mutating func cancel() {
        generation += 1
        isPending = false
    }

    mutating func complete(generation expected: Int) -> Bool {
        guard isPending, generation == expected else {
            return false
        }

        isPending = false
        return true
    }
}

struct RecognitionStabilizer {
    let requiredDuration: TimeInterval

    private(set) var signature: String?
    private(set) var firstSeenAt: TimeInterval?

    init(requiredDuration: TimeInterval = 0.35) {
        self.requiredDuration = requiredDuration
    }

    mutating func observe(
        signature newSignature: String,
        at timestamp: TimeInterval
    ) -> Bool {
        if signature != newSignature {
            signature = newSignature
            firstSeenAt = timestamp
            return false
        }

        guard let firstSeenAt else {
            self.firstSeenAt = timestamp
            return false
        }

        return timestamp - firstSeenAt >= requiredDuration
    }

    mutating func reset() {
        signature = nil
        firstSeenAt = nil
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
    case reading
    case ready
    case alreadyAdded
    case tooManyTags
    case incompatible(String)
}

enum CameraState: Equatable {
    case preparing
    case ready
    case denied
    case unsupported
    case failed(String)
}
