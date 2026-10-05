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

        let prices = usable.compactMap { item in
            priceMatch(
                item,
                inheritedCurrency: nearbyCurrencyToken(
                    for: item,
                    in: usable
                )
            )
        } + splitPriceMatches(in: usable)
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

        let rankedPairs = pairs.sorted { $0.2 > $1.2 }

        guard let bestPair = rankedPairs.first else {
            return nil
        }

        // Do not guess when two materially different interpretations are
        // almost equally plausible. This is common on loyalty/promo labels.
        if let competitor = rankedPairs.dropFirst().first(where: {
            $0.0.value != bestPair.0.value ||
            $0.1.normalizedValue != bestPair.1.normalizedValue ||
            $0.1.dimension != bestPair.1.dimension
        }),
           bestPair.2 - competitor.2 < 0.45 {
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

    private static func priceMatch(
        _ item: ScannedText,
        inheritedCurrency: String? = nil
    ) -> PriceMatch? {
        let text = item.transcript
        let normalizedPriceText = RetailLexicon.normalizePriceText(text)
        let directCurrency = currencyToken(in: text)
        let currency = directCurrency ?? inheritedCurrency

        guard let value = priceValue(
            in: normalizedPriceText,
            currency: currency
        ) else {
            return nil
        }

        let lower = text.lowercased()

        var score = Double(item.confidence) * 2.0
        score += min(Double(item.bounds.height / 24.0), 2.0)

        // Unit-price lines are reference prices, not the package price.
        // Never allow them to win just because they also contain a currency.
        if RetailLexicon.looksLikeReferenceUnitPrice(lower) {
            return nil
        }

        // A line like "1.50 L" is quantity, not price. One-line
        // price+quantity is accepted only when currency makes the price explicit.
        if containsAnySupportedUnit(lower), directCurrency == nil {
            return nil
        }

        if directCurrency != nil {
            score += 2.0
        } else if currency != nil {
            score += 1.0
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
        let currencyPattern =
            "(?:" + RetailLexicon.currencyRegexAlternation + ")"

        // CLDR permits the currency symbol before, after, or in the decimal
        // position (for example 12€50).
        let currencyAsDecimalPattern =
            #"(?i)(?<!\d)(\d{1,9})\s*"# + currencyPattern
            + #"\s*(\d{2})(?!\d)"#

        if let match = firstMatch(
            pattern: currencyAsDecimalPattern,
            in: text
        ),
           let wholeRaw = capturedString(
            match,
            group: 1,
            text: text
           ),
           let centsRaw = capturedString(
            match,
            group: 2,
            text: text
           ),
           let whole = Decimal(
            string: wholeRaw,
            locale: Locale(identifier: "en_US_POSIX")
           ),
           let cents = Decimal(
            string: centsRaw,
            locale: Locale(identifier: "en_US_POSIX")
           ) {
            return whole + (cents / 100)
        }

        // Accept Western, Indian and apostrophe/space grouping styles.
        let groupedDecimalPattern =
            #"(?<!\d)(\d{1,3}(?:[\s\.,'’]\d{2,3})+[\.,]\d{2})(?!\d)"#
        let decimalPattern =
            #"(?<!\d)(\d{1,9}[\.,]\d{2})(?!\d)"#

        for pattern in [groupedDecimalPattern, decimalPattern] {
            if let match = firstMatch(pattern: pattern, in: text),
               let raw = capturedString(match, group: 1, text: text),
               let value = decimal(raw) {
                return value
            }
        }

        // Common European zero-cents notation: 4,- / 4.- / 4.–
        let groupedZeroCentsPattern =
            #"(?<!\d)(\d{1,3}(?:[\s\.,'’]\d{2,3})+)\s*[\.,]\s*-(?!\d)"#
        let zeroCentsPattern =
            #"(?<!\d)(\d{1,9})\s*[\.,]\s*-(?!\d)"#

        for pattern in [groupedZeroCentsPattern, zeroCentsPattern] {
            if let match = firstMatch(pattern: pattern, in: text),
               let raw = capturedString(match, group: 1, text: text),
               let value = integerWithGrouping(raw) {
                return value
            }
        }

        // OCR can occasionally drop the decimal separator and return "4 99".
        // Only repair that form when a currency marker disambiguates it.
        if currency != nil {
            let missingSeparatorPattern =
                #"(?<!\d)(\d{1,9})\s+(\d{2})(?!\d)"#
            if let match = firstMatch(
                pattern: missingSeparatorPattern,
                in: text
            ),
               let wholeRaw = capturedString(
                match,
                group: 1,
                text: text
               ),
               let centsRaw = capturedString(
                match,
                group: 2,
                text: text
               ),
               let whole = Decimal(
                string: wholeRaw,
                locale: Locale(identifier: "en_US_POSIX")
               ),
               let cents = Decimal(
                string: centsRaw,
                locale: Locale(identifier: "en_US_POSIX")
               ) {
                return whole + (cents / 100)
            }
        }

        // Integer-only prices are accepted only when currency is explicit on
        // the same OCR item or on a nearby currency-only fragment.
        guard currency != nil else {
            return nil
        }

        // If currency came from a nearby standalone OCR fragment, a bare
        // integer such as "4" is a valid package price.
        let bareIntegerPattern = #"^\s*(\d{1,9})\s*$"#
        if let match = firstMatch(
            pattern: bareIntegerPattern,
            in: text
        ),
           let raw = capturedString(
            match,
            group: 1,
            text: text
           ),
           let value = Decimal(
            string: raw,
            locale: Locale(identifier: "en_US_POSIX")
           ) {
            return value
        }

        let groupedNumber =
            #"(\d{1,3}(?:[\s\.,'’]\d{2,3})+)"#
        let groupedPrefixed = #"(?i)"# + currencyPattern + #"\s*"# + groupedNumber
        let groupedSuffixed = #"(?i)(?<!\d)"# + groupedNumber + #"\s*"# + currencyPattern

        for pattern in [groupedPrefixed, groupedSuffixed] {
            if let match = firstMatch(pattern: pattern, in: text),
               let raw = capturedString(match, group: 1, text: text),
               let value = integerWithGrouping(raw) {
                return value
            }
        }

        let prefixed =
            #"(?i)"# + currencyPattern + #"\s*(\d{1,9})(?![\d\.,])"#
        let suffixed =
            #"(?i)(?<![\d\.,])(\d{1,9})\s*"# + currencyPattern

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
            let lower = item.transcript.lowercased()
            guard !RetailLexicon.looksLikeReferenceUnitPrice(lower),
                  !containsAnySupportedUnit(lower),
                  let value = plainIntegerValue(
                    in: item.transcript,
                    digits: 1...9
                  ) else {
                return nil
            }
            return (item, value)
        }

        let fractionCandidates = items.compactMap { item -> (ScannedText, Decimal)? in
            let lower = item.transcript.lowercased()
            let packagePriceSuffix =
                RetailLexicon.looksLikePackagePriceSuffix(lower)

            guard !RetailLexicon.looksLikeReferenceUnitPrice(lower),
                  (!containsAnySupportedUnit(lower) || packagePriceSuffix),
                  let value = plainIntegerValue(
                    in: item.transcript,
                    digits: 2...2
                  ) else {
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
        let normalized = RetailLexicon.normalizePriceText(text)
        let currency =
            "(?:" + RetailLexicon.currencyRegexAlternation + ")?"
        let pattern = #"(?i)^\s*"# + currency + #"\s*(\d{"#
            + String(digits.lowerBound) + #","# + String(digits.upperBound)
            + #"})\s*"# + currency + #"\s*$"#

        guard let match = firstMatch(
            pattern: pattern,
            in: normalized
        ),
              let raw = capturedString(
                match,
                group: 1,
                text: normalized
              ) else {
            return nil
        }

        return Decimal(
            string: raw,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func quantityMatch(_ item: ScannedText) -> QuantityMatch? {
        let text = RetailLexicon.normalizeUnicode(item.transcript)
        let lower = text.lowercased()

        if RetailLexicon.looksLikeReferenceUnitPrice(lower) ||
            RetailLexicon.looksLikePackagePriceSuffix(lower) {
            return nil
        }

        let numberPattern =
            #"(?<![\d\.,])(\d{1,3}(?:\s\d{3})+(?:[\.,]\d+)?|\d+(?:[\.,]\d+)?)"#
        let unitPattern =
            "(" + RetailLexicon.unitRegexAlternation + ")"

        let multipackPattern =
            #"(?i)(\d{1,3})\s*x\s*"# + numberPattern + #"\s*"# + unitPattern
        if let match = firstMatch(pattern: multipackPattern, in: text),
           let count = capturedDecimal(match, group: 1, text: text),
           let sizeRaw = capturedString(match, group: 2, text: text),
           let unit = capturedString(match, group: 3, text: text),
           let size = quantityDecimal(sizeRaw, unit: unit),
           let normalized = normalize(value: count * size, unit: unit) {
            return QuantityMatch(
                normalizedValue: normalized.value,
                dimension: normalized.dimension,
                score: quantityScore(item),
                source: item
            )
        }

        let simplePattern = #"(?i)"# + numberPattern + #"\s*"# + unitPattern
        guard let match = firstMatch(pattern: simplePattern, in: text),
              let valueRaw = capturedString(match, group: 1, text: text),
              let unit = capturedString(match, group: 2, text: text),
              let value = quantityDecimal(valueRaw, unit: unit),
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

    private static func quantityDecimal(
        _ raw: String,
        unit rawUnit: String
    ) -> Decimal? {
        let unit = rawUnit.lowercased()
        let compact = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")

        // On grocery labels, 1.500 g / 1,500 ml conventionally means
        // 1500 base units. For kg/L/cl the same notation remains decimal.
        let groupedBaseUnits = [
            "g", "gr", "гр", "г",
            "ml", "мл",
            "item", "items", "pc", "pcs", "шт"
        ]

        if groupedBaseUnits.contains(unit) {
            let groupingPattern = #"^([1-9]\d{0,2})[\.,](\d{3})$"#
            if let match = firstMatch(
                pattern: groupingPattern,
                in: compact
            ),
               let whole = capturedString(
                match,
                group: 1,
                text: compact
               ),
               let tail = capturedString(
                match,
                group: 2,
                text: compact
               ) {
                return Decimal(
                    string: whole + tail,
                    locale: Locale(identifier: "en_US_POSIX")
                )
            }
        }

        return decimal(raw)
    }

    private static func quantityScore(_ item: ScannedText) -> Double {
        Double(item.confidence) * 2.0 + min(Double(item.bounds.height / 24.0), 1.5)
    }

    private static func normalize(
        value: Decimal,
        unit rawUnit: String
    ) -> (value: Decimal, dimension: QuantityDimension)? {
        guard let definition = RetailLexicon.unitDefinition(
            for: rawUnit
        ) else {
            return nil
        }

        return (
            value * definition.multiplier,
            definition.dimension
        )
    }

    private static func containsAnySupportedUnit(
        _ text: String
    ) -> Bool {
        let pattern =
            #"(?i)(?<![\p{L}\p{N}])(?:"#
            + RetailLexicon.unitRegexAlternation
            + #")(?![\p{L}\p{N}])"#

        return firstMatch(
            pattern: pattern,
            in: RetailLexicon.normalizeUnicode(text)
        ) != nil
    }

    private static func nearbyCurrencyToken(
        for item: ScannedText,
        in items: [ScannedText]
    ) -> String? {
        let reachX = max(42, item.bounds.height * 1.35)
        let reachY = max(28, item.bounds.height * 0.85)
        let searchBounds = item.bounds.insetBy(
            dx: -reachX,
            dy: -reachY
        )

        return items
            .filter { $0.id != item.id }
            .compactMap { candidate -> (String, CGFloat)? in
                guard searchBounds.intersects(candidate.bounds),
                      let token = standaloneCurrencyToken(
                        in: candidate.transcript
                      ) else {
                    return nil
                }

                let dx = candidate.bounds.midX - item.bounds.midX
                let dy = candidate.bounds.midY - item.bounds.midY
                return (token, (dx * dx) + (dy * dy))
            }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    private static func standaloneCurrencyToken(
        in text: String
    ) -> String? {
        let normalized = RetailLexicon.normalizePriceText(text)
        let pattern =
            #"(?i)^\s*(?:"# + RetailLexicon.currencyRegexAlternation
            + #")\s*$"#

        guard firstMatch(
            pattern: pattern,
            in: normalized
        ) != nil,
              let canonical = RetailLexicon.canonicalCurrency(
                in: normalized
              ) else {
            return nil
        }

        return RetailLexicon.displayCurrency(
            canonical: canonical
        )
    }

    private static func currencyToken(
        in text: String
    ) -> String? {
        guard let canonical = RetailLexicon.canonicalCurrency(
            in: RetailLexicon.normalizePriceText(text)
        ) else {
            return nil
        }

        return RetailLexicon.displayCurrency(
            canonical: canonical
        )
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

    private static func integerWithGrouping(
        _ raw: String
    ) -> Decimal? {
        let normalized = RetailLexicon.normalizeUnicode(raw)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")

        return Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func decimal(_ raw: String) -> Decimal? {
        var value = RetailLexicon.normalizeUnicode(raw)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")

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

        return result.flatMap(refineCluster)
    }

    private static func refineCluster(
        _ items: [ScannedText]
    ) -> [[ScannedText]] {
        guard let split = splitMixedCluster(items) else {
            return [items]
        }

        // Recurse so a connected mega-cluster containing 3+ shelf tags does
        // not get flattened into only two candidates.
        return split.flatMap(refineCluster)
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
            candidate.clusters.allSatisfy(isResolvableSegment)
        }

        return candidates.max(by: { $0.gap < $1.gap })?.clusters
    }

    private static func isResolvableSegment(
        _ items: [ScannedText]
    ) -> Bool {
        if PriceTagParser.parse(cluster: items) != nil {
            return true
        }

        guard items.count >= 4 else {
            return false
        }

        let nestedCandidates = [
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

        return nestedCandidates.contains { candidate in
            candidate.clusters.count == 2 &&
            candidate.clusters.allSatisfy(isResolvableSegment)
        }
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
