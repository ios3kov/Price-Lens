import CoreGraphics
import Foundation

enum PriceTagParser {
    private struct PriceMatch {
        let value: Decimal
        let currency: String?
        let score: Double
        let source: ScannedText
    }

    private struct QuantityMatch {
        let normalizedValue: Decimal
        let dimension: QuantityDimension
        let score: Double
        let source: ScannedText
    }

    static func parse(cluster: [ScannedText]) -> ProductCandidate? {
        let usable = cluster.filter {
            !$0.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.confidence >= 0.35
        }

        guard !usable.isEmpty else { return nil }

        let prices = usable.compactMap(priceMatch) + splitPriceMatches(in: usable)
        let quantities = usable.compactMap(quantityMatch)

        let pairs = prices.flatMap { price in
            quantities.compactMap { quantity -> (PriceMatch, QuantityMatch, Double)? in
                // A bare line such as "1.50 L" must not be used as both price
                // and package size. The same OCR item is only acceptable for
                // both roles when an explicit currency marker disambiguates it.
                if price.source.id == quantity.source.id,
                   currencyToken(in: price.source.transcript) == nil {
                    return nil
                }

                return (price, quantity, price.score + quantity.score)
            }
        }

        guard let bestPair = pairs.max(by: { $0.2 < $1.2 }) else {
            return nil
        }

        let price = bestPair.0
        let quantity = bestPair.1

        // Avoid accepting a weak accidental number/unit pair.
        guard price.score >= 1.0, quantity.score >= 1.0 else {
            return nil
        }

        let bounds = usable.reduce(CGRect.null) { partial, item in
            partial.union(item.bounds)
        }

        let clusterCurrency = price.currency ?? usable.lazy
            .compactMap { currencyToken(in: $0.transcript) }
            .first

        return ProductCandidate(
            id: UUID(),
            price: price.value,
            currencyToken: clusterCurrency,
            normalizedQuantity: quantity.normalizedValue,
            dimension: quantity.dimension,
            sourceBounds: bounds,
            confidence: min(price.source.confidence, quantity.source.confidence),
            rawText: usable.map(\.transcript).joined(separator: " | ")
        )
    }

    private static func priceMatch(_ item: ScannedText) -> PriceMatch? {
        let text = item.transcript
        let currency = currencyToken(in: text)

        guard let value = priceValue(in: text, currency: currency) else {
            return nil
        }

        let lower = text.lowercased()

        var score = Double(item.confidence) * 2.0
        score += min(Double(item.bounds.height / 24.0), 2.0)

        // Unit-price lines are reference prices, not the package price.
        // Never allow them to win just because they also contain a currency.
        if containsUnitPriceCue(lower) {
            return nil
        }

        // A line like "1.50 L" is quantity, not price. One-line
        // price+quantity is accepted only when currency makes the price explicit.
        if containsAnySupportedUnit(lower), currency == nil {
            return nil
        }

        if currency != nil {
            score += 2.0
        }

        return PriceMatch(
            value: value,
            currency: currency,
            score: score,
            source: item
        )
    }

    private static func priceValue(
        in text: String,
        currency: String?
    ) -> Decimal? {
        let decimalPattern = #"(?<!\d)(\d{1,4}[\.,]\d{2})(?!\d)"#

        if let match = firstMatch(pattern: decimalPattern, in: text),
           let raw = capturedString(match, group: 1, text: text),
           let value = decimal(raw) {
            return value
        }

        // Common European zero-cents notation: 4,- / 4.- / 4.–
        let zeroCentsPattern = #"(?<!\d)(\d{1,4})\s*[\.,]\s*[-–—](?!\d)"#
        if let match = firstMatch(pattern: zeroCentsPattern, in: text),
           let raw = capturedString(match, group: 1, text: text) {
            return Decimal(
                string: raw,
                locale: Locale(identifier: "en_US_POSIX")
            )
        }

        // Integer-only prices are accepted only when the currency is directly
        // adjacent, so "500 ml €4" yields 4 rather than 500.
        guard currency != nil else {
            return nil
        }

        let currencyPattern = #"(?:€|\$|£|EUR|USD|GBP|BAM|KM)"#
        let prefixed = #"(?i)"# + currencyPattern + #"\s*(\d{1,4})(?![\d\.,])"#
        let suffixed = #"(?i)(?<![\d\.,])(\d{1,4})\s*"# + currencyPattern

        for pattern in [prefixed, suffixed] {
            if let match = firstMatch(pattern: pattern, in: text),
               let raw = capturedString(match, group: 1, text: text) {
                return Decimal(
                    string: raw,
                    locale: Locale(identifier: "en_US_POSIX")
                )
            }
        }

        return nil
    }

    private static func splitPriceMatches(
        in items: [ScannedText]
    ) -> [PriceMatch] {
        let wholeCandidates = items.compactMap { item -> (ScannedText, Decimal)? in
            guard !containsUnitPriceCue(item.transcript.lowercased()),
                  !containsAnySupportedUnit(item.transcript.lowercased()),
                  let value = plainIntegerValue(in: item.transcript, digits: 1...4) else {
                return nil
            }
            return (item, value)
        }

        let fractionCandidates = items.compactMap { item -> (ScannedText, Decimal)? in
            guard !containsUnitPriceCue(item.transcript.lowercased()),
                  !containsAnySupportedUnit(item.transcript.lowercased()),
                  let value = plainIntegerValue(in: item.transcript, digits: 2...2) else {
                return nil
            }
            return (item, value)
        }

        return wholeCandidates.flatMap { wholeItem, wholeValue in
            fractionCandidates.compactMap { fractionItem, fractionValue in
                guard wholeItem.id != fractionItem.id,
                      looksLikeSplitPrice(
                        whole: wholeItem,
                        fraction: fractionItem
                      ) else {
                    return nil
                }

                let price = wholeValue + (fractionValue / 100)
                let combinedBounds = wholeItem.bounds.union(fractionItem.bounds)
                let combinedTranscript = wholeItem.transcript + "." + fractionItem.transcript
                let currency = currencyToken(in: wholeItem.transcript)
                    ?? currencyToken(in: fractionItem.transcript)

                var score =
                    Double(min(wholeItem.confidence, fractionItem.confidence)) * 2.0
                    + min(Double(combinedBounds.height / 24.0), 2.0)
                    + 1.0

                if currency != nil {
                    score += 2.0
                }

                let source = ScannedText(
                    id: UUID(),
                    transcript: combinedTranscript,
                    bounds: combinedBounds,
                    confidence: min(wholeItem.confidence, fractionItem.confidence)
                )

                return PriceMatch(
                    value: price,
                    currency: currency,
                    score: score,
                    source: source
                )
            }
        }
    }

    private static func looksLikeSplitPrice(
        whole: ScannedText,
        fraction: ScannedText
    ) -> Bool {
        let wholeBounds = whole.bounds
        let fractionBounds = fraction.bounds

        guard fractionBounds.midX > wholeBounds.midX else {
            return false
        }

        let horizontalGap = fractionBounds.minX - wholeBounds.maxX
        let maxGap = max(26, wholeBounds.height * 0.9)

        guard horizontalGap <= maxGap else {
            return false
        }

        let verticalCenterDistance = abs(
            fractionBounds.midY - wholeBounds.midY
        )
        let allowedVerticalDistance = max(
            22,
            max(wholeBounds.height, fractionBounds.height) * 0.72
        )

        guard verticalCenterDistance <= allowedVerticalDistance else {
            return false
        }

        guard fractionBounds.height >= wholeBounds.height * 0.30,
              fractionBounds.height <= wholeBounds.height * 1.35 else {
            return false
        }

        // If the cents fragment itself has a currency marker, that is strong
        // evidence that it belongs to the shelf price. Otherwise require the
        // cents to be visually smaller than the whole-number part.
        if currencyToken(in: fraction.transcript) == nil,
           fractionBounds.height > wholeBounds.height * 0.87 {
            return false
        }

        return true
    }

    private static func plainIntegerValue(
        in text: String,
        digits: ClosedRange<Int>
    ) -> Decimal? {
        let currency = #"(?:€|\$|£|EUR|USD|GBP|BAM|KM)?"#
        let pattern = #"(?i)^\s*"# + currency + #"\s*(\d{"#
            + String(digits.lowerBound) + #","# + String(digits.upperBound)
            + #"})\s*"# + currency + #"\s*$"#

        guard let match = firstMatch(pattern: pattern, in: text),
              let raw = capturedString(match, group: 1, text: text) else {
            return nil
        }

        return Decimal(
            string: raw,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func quantityMatch(_ item: ScannedText) -> QuantityMatch? {
        let text = item.transcript
        let lower = text.lowercased()

        if containsUnitPriceCue(lower) {
            return nil
        }

        let multipackPattern = #"(?i)(\d{1,3})\s*[xх×]\s*(\d+(?:[\.,]\d+)?)\s*(kg|кг|ml|мл|cl|l|л|gr|гр|g|г|items?|pcs?|pc|шт)"#
        if let match = firstMatch(pattern: multipackPattern, in: text),
           let count = capturedDecimal(match, group: 1, text: text),
           let size = capturedDecimal(match, group: 2, text: text),
           let unit = capturedString(match, group: 3, text: text),
           let normalized = normalize(value: count * size, unit: unit) {
            return QuantityMatch(
                normalizedValue: normalized.value,
                dimension: normalized.dimension,
                score: quantityScore(item),
                source: item
            )
        }

        let simplePattern = #"(?i)(\d+(?:[\.,]\d+)?)\s*(kg|кг|ml|мл|cl|l|л|gr|гр|g|г|items?|pcs?|pc|шт)"#
        guard let match = firstMatch(pattern: simplePattern, in: text),
              let value = capturedDecimal(match, group: 1, text: text),
              let unit = capturedString(match, group: 2, text: text),
              let normalized = normalize(value: value, unit: unit) else {
            return nil
        }

        return QuantityMatch(
            normalizedValue: normalized.value,
            dimension: normalized.dimension,
            score: quantityScore(item),
            source: item
        )
    }

    private static func quantityScore(_ item: ScannedText) -> Double {
        Double(item.confidence) * 2.0 + min(Double(item.bounds.height / 24.0), 1.5)
    }

    private static func normalize(
        value: Decimal,
        unit rawUnit: String
    ) -> (value: Decimal, dimension: QuantityDimension)? {
        let unit = rawUnit.lowercased()

        switch unit {
        case "kg", "кг":
            return (value, .mass)
        case "g", "gr", "гр", "г":
            return (value / 1000, .mass)
        case "l", "л":
            return (value, .volume)
        case "ml", "мл":
            return (value / 1000, .volume)
        case "cl":
            return (value / 100, .volume)
        case "item", "items", "pc", "pcs", "шт":
            return (value, .count)
        default:
            return nil
        }
    }

    private static func containsUnitPriceCue(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "")
        return compact.contains("/kg") ||
            compact.contains("/кг") ||
            compact.contains("/l") ||
            compact.contains("/л") ||
            compact.contains("/100g") ||
            compact.contains("/100ml") ||
            text.contains("per kg") ||
            text.contains("per l") ||
            text.contains("za kg") ||
            text.contains("za 1 kg")
    }

    private static func containsAnySupportedUnit(_ text: String) -> Bool {
        ["kg", "кг", " ml", "мл", " cl", " l", " л", " g", "гр", " г", "item", "pc", "pcs", "шт"]
            .contains(where: text.contains)
    }

    private static func currencyToken(in text: String) -> String? {
        let upper = text.uppercased()
        for token in ["BAM", "EUR", "USD", "GBP", "KM", "€", "$", "£"] {
            if upper.contains(token) {
                return token
            }
        }
        return nil
    }

    private static func firstMatch(
        pattern: String,
        in text: String
    ) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        return regex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }

    private static func capturedString(
        _ match: NSTextCheckingResult,
        group: Int,
        text: String
    ) -> String? {
        guard let range = Range(match.range(at: group), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func capturedDecimal(
        _ match: NSTextCheckingResult,
        group: Int,
        text: String
    ) -> Decimal? {
        guard let string = capturedString(match, group: group, text: text) else {
            return nil
        }
        return decimal(string)
    }

    private static func decimal(_ raw: String) -> Decimal? {
        var value = raw.replacingOccurrences(of: " ", with: "")

        if value.contains(","), value.contains(".") {
            let comma = value.lastIndex(of: ",")
            let dot = value.lastIndex(of: ".")

            if let comma, let dot, comma > dot {
                value = value.replacingOccurrences(of: ".", with: "")
                value = value.replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        } else {
            value = value.replacingOccurrences(of: ",", with: ".")
        }

        return Decimal(
            string: value,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

enum TagClusterer {
    static func clusters(from items: [ScannedText]) -> [[ScannedText]] {
        let usable = items.filter { $0.confidence >= 0.35 }
        guard usable.count > 1 else {
            return usable.isEmpty ? [] : [usable]
        }

        var visited = Set<UUID>()
        var result: [[ScannedText]] = []

        for seed in usable where !visited.contains(seed.id) {
            var queue = [seed]
            var cluster: [ScannedText] = []
            visited.insert(seed.id)

            while let current = queue.popLast() {
                cluster.append(current)

                for candidate in usable where !visited.contains(candidate.id) {
                    if shouldJoin(current.bounds, candidate.bounds) {
                        visited.insert(candidate.id)
                        queue.append(candidate)
                    }
                }
            }

            result.append(cluster)
        }

        if result.count == 1,
           let split = splitMixedCluster(usable) {
            // Prefer a validated spatial split over a mixed mega-cluster.
            // Both halves must independently parse as real price-tag candidates,
            // otherwise keeping the original cluster is safer than guessing.
            return split
        }

        return result
    }

    private static func shouldJoin(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let expanded = lhs.insetBy(
            dx: -max(52, lhs.width * 0.35),
            dy: -max(44, lhs.height * 2.2)
        )
        return expanded.intersects(rhs)
    }

    private enum SplitAxis {
        case horizontal
        case vertical
    }

    private struct SplitCandidate {
        let clusters: [[ScannedText]]
        let gap: CGFloat
    }

    private static func splitMixedCluster(
        _ items: [ScannedText]
    ) -> [[ScannedText]]? {
        guard items.count >= 4 else { return nil }

        let candidates = [
            largestGapSplit(
                items,
                axis: .horizontal,
                minimumGap: 64
            ),
            largestGapSplit(
                items,
                axis: .vertical,
                minimumGap: 56
            )
        ]
        .compactMap { $0 }
        .filter { candidate in
            candidate.clusters.count == 2 &&
            candidate.clusters.allSatisfy {
                PriceTagParser.parse(cluster: $0) != nil
            }
        }

        return candidates.max(by: { $0.gap < $1.gap })?.clusters
    }

    private static func largestGapSplit(
        _ items: [ScannedText],
        axis: SplitAxis,
        minimumGap: CGFloat
    ) -> SplitCandidate? {
        let coordinate: (ScannedText) -> CGFloat = { item in
            switch axis {
            case .horizontal:
                return item.bounds.midX
            case .vertical:
                return item.bounds.midY
            }
        }

        let sorted = items.sorted {
            coordinate($0) < coordinate($1)
        }

        var bestIndex: Int?
        var bestGap: CGFloat = 0

        for index in 0..<(sorted.count - 1) {
            let gap = coordinate(sorted[index + 1]) - coordinate(sorted[index])
            if gap > bestGap {
                bestGap = gap
                bestIndex = index
            }
        }

        guard let bestIndex, bestGap >= minimumGap else {
            return nil
        }

        let first = Array(sorted[0...bestIndex])
        let second = Array(sorted[(bestIndex + 1)...])

        guard !first.isEmpty, !second.isEmpty else {
            return nil
        }

        return SplitCandidate(
            clusters: [first, second],
            gap: bestGap
        )
    }
}
