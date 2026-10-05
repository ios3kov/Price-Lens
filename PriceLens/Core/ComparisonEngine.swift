import Foundation

enum ComparisonEngine {
    static func compare(
        left: ProductCandidate,
        right: ProductCandidate
    ) -> Result<PriceComparison, ComparisonFailure> {
        guard left.dimension == right.dimension else {
            return .failure(.incompatibleDimensions)
        }

        if let leftCurrency = normalizedCurrency(left.currencyToken),
           let rightCurrency = normalizedCurrency(right.currencyToken),
           leftCurrency != rightCurrency {
            return .failure(.differentCurrencies)
        }

        let leftUnit = left.unitPrice
        let rightUnit = right.unitPrice

        guard leftUnit > 0, rightUnit > 0 else {
            return .failure(.incompatibleDimensions)
        }

        if leftUnit == rightUnit {
            return .success(
                PriceComparison(
                    left: left,
                    right: right,
                    winner: .equal,
                    cheaperPercent: 0
                )
            )
        }

        let cheaper = minDecimal(leftUnit, rightUnit)
        let expensive = maxDecimal(leftUnit, rightUnit)
        let percent = ((expensive - cheaper) / expensive) * 100
        let winner: WinnerSide = leftUnit < rightUnit ? .left : .right

        return .success(
            PriceComparison(
                left: left,
                right: right,
                winner: winner,
                cheaperPercent: percent
            )
        )
    }

    static func normalizedCurrency(_ token: String?) -> String? {
        guard let token else {
            return nil
        }

        return RetailLexicon.canonicalCurrency(in: token)
            ?? token.uppercased()
    }

    private static func minDecimal(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        lhs < rhs ? lhs : rhs
    }

    private static func maxDecimal(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        lhs > rhs ? lhs : rhs
    }
}

extension ComparisonFailure: Error {}
