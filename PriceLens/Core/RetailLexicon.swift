import Foundation

enum RetailLexicon {
    struct UnitDefinition: Equatable {
        let dimension: QuantityDimension
        /// Multiplier into Price Lens base units: kg, L or item.
        let multiplier: Decimal
    }

    private static let isoCurrencyCodes = Set(
        Locale.Currency.isoCurrencies.map {
            $0.identifier.uppercased()
        }
    )

    /// Currency symbols come from the system CLDR/ICU locale inventory.
    /// Symbols shared by multiple currencies stay ambiguous instead of being
    /// silently mapped to one country.
    private static let localeCurrencySymbolCodes: [String: Set<String>] = {
        var values: [String: Set<String>] = [:]

        for identifier in Locale.availableIdentifiers {
            let locale = Locale(identifier: identifier)
            guard let code = locale.currency?.identifier.uppercased(),
                  isoCurrencyCodes.contains(code),
                  let rawSymbol = locale.currencySymbol else {
                continue
            }

            let symbol = rawSymbol.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !symbol.isEmpty,
                  symbol != "¤",
                  symbol.uppercased() != code else {
                continue
            }

            // One-letter alphabetic currency symbols collide with OCR units
            // such as g and L, so do not infer them from the global locale
            // catalog. Admit important retail forms explicitly below.
            if symbol.count == 1,
               let character = symbol.first,
               character.isLetter {
                continue
            }

            values[symbol, default: Set<String>()].insert(code)
        }

        return values
    }()

    private static let localeCurrencySymbols =
        localeCurrencySymbolCodes.keys.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs < rhs
            }
            return lhs.count > rhs.count
        }

    /// CLDR/ISO currencies that conventionally use three fractional digits.
    /// Zero-fraction currencies already work through integer-price parsing.
    private static let threeFractionCurrencyCodes: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"
    ]

    /// Symbols that are unambiguous enough to canonicalize without a locale.
    /// Ambiguous "$" stays "$" unless it has a regional prefix.
    private static let symbolCurrencies: [(String, String)] = [
        ("HK$", "HKD"),
        ("NT$", "TWD"),
        ("NZ$", "NZD"),
        ("A$", "AUD"),
        ("C$", "CAD"),
        ("S$", "SGD"),
        ("R$", "BRL"),
        ("R", "ZAR"),

        ("د.إ", "AED"),
        ("ر.س", "SAR"),
        ("﷼", "IRR"),
        ("€", "EUR"),
        ("£", "GBP"),
        ("₽", "RUB"),
        ("₴", "UAH"),
        ("₸", "KZT"),
        ("₺", "TRY"),
        ("₾", "GEL"),
        ("₼", "AZN"),
        ("₹", "INR"),
        ("₩", "KRW"),
        ("₫", "VND"),
        ("₪", "ILS"),
        ("₱", "PHP"),
        ("฿", "THB"),
        ("₦", "NGN"),
        ("₡", "CRC"),
        ("₲", "PYG"),
        ("₵", "GHS"),
        ("₭", "LAK"),
        ("₮", "MNT"),
        ("؋", "AFN"),
        ("৳", "BDT"),
        ("៛", "KHR"),
        ("د.ك", "KWD"),
        ("د.ب", "BHD"),
        ("ر.ق", "QAR"),
        ("ر.ع.", "OMR"),
        ("د.ا", "JOD"),
        ("ج.م", "EGP"),
        ("ل.ل", "LBP"),
        ("د.ت", "TND"),
        ("د.ج", "DZD"),
        ("د.م.", "MAD"),
        // Bare yen/yuan is intentionally not canonicalized: ¥ is shared
        // across JPY/CNY contexts. The display token is preserved instead.
        ("元", "CNY")
    ]

    private static let wordCurrencyAliases: [String: String] = [
        "РУБ": "RUB",
        "РУБЛЬ": "RUB",
        "РУБЛЯ": "RUB",
        "РУБЛЕЙ": "RUB",
        "Р": "RUB",
        "ГРН": "UAH",
        "ТГ": "KZT",
        "ТЕНГЕ": "KZT",
        "ЛАРИ": "GEL",
        "МАНАТ": "AZN",
        "KM": "BAM",
        "KČ": "CZK",
        "ZŁ": "PLN",
        "LEI": "RON",
        "ЛВ": "BGN",
        "DIN": "RSD",
        "ДИН": "RSD",
        "FT": "HUF",
        "RM": "MYR",
        "RP": "IDR",
        "KR": "KR"
    ]

    private static let unitDefinitions: [String: UnitDefinition] = {
        var values: [String: UnitDefinition] = [:]

        func add(
            _ aliases: [String],
            dimension: QuantityDimension,
            multiplier: Decimal
        ) {
            let definition = UnitDefinition(
                dimension: dimension,
                multiplier: multiplier
            )
            for alias in aliases {
                values[canonicalWord(alias)] = definition
            }
        }

        add(
            [
                "kg", "kgs", "kilogram", "kilograms",
                "кг", "килограмм", "килограмма", "килограммов",
                "公斤", "千克", "킬로그램", "كجم", "كيلوغرام"
            ],
            dimension: .mass,
            multiplier: 1
        )
        add(
            [
                "g", "gr", "gram", "grams",
                "гр", "г", "грамм", "грамма", "граммов",
                "克", "그램", "غ", "جرام"
            ],
            dimension: .mass,
            multiplier: Decimal(string: "0.001")!
        )
        add(
            ["mg", "мг", "毫克", "밀리그램", "مغ"],
            dimension: .mass,
            multiplier: Decimal(string: "0.000001")!
        )
        add(
            ["mcg", "ug", "µg", "μg", "мкг"],
            dimension: .mass,
            multiplier: Decimal(string: "0.000000001")!
        )
        add(
            ["lb", "lbs", "pound", "pounds"],
            dimension: .mass,
            multiplier: Decimal(string: "0.45359237")!
        )
        add(
            ["oz", "ounce", "ounces"],
            dimension: .mass,
            multiplier: Decimal(string: "0.028349523125")!
        )

        add(
            [
                "l", "lt", "liter", "liters", "litre", "litres",
                "л", "литр", "литра", "литров",
                "升", "리터", "لتر"
            ],
            dimension: .volume,
            multiplier: 1
        )
        add(
            ["dl", "дл"],
            dimension: .volume,
            multiplier: Decimal(string: "0.1")!
        )
        add(
            ["cl", "сл"],
            dimension: .volume,
            multiplier: Decimal(string: "0.01")!
        )
        add(
            [
                "ml", "milliliter", "milliliters", "millilitre", "millilitres",
                "мл", "миллилитр", "миллилитров",
                "毫升", "밀리리터", "مل"
            ],
            dimension: .volume,
            multiplier: Decimal(string: "0.001")!
        )
        add(
            ["ul", "µl", "μl", "мкл"],
            dimension: .volume,
            multiplier: Decimal(string: "0.000001")!
        )
        add(
            ["cc", "cm3"],
            dimension: .volume,
            multiplier: Decimal(string: "0.001")!
        )
        add(
            [
                "fl oz", "floz", "fluid ounce", "fluid ounces",
                "us fl oz", "us fluid ounce", "us fluid ounces"
            ],
            dimension: .volume,
            multiplier: Decimal(string: "0.0295735295625")!
        )
        add(
            ["imp fl oz", "imperial fl oz", "imperial fluid ounce"],
            dimension: .volume,
            multiplier: Decimal(string: "0.0284130625")!
        )
        add(
            ["pt", "pint", "pints", "us pt", "us pint"],
            dimension: .volume,
            multiplier: Decimal(string: "0.473176473")!
        )
        add(
            ["imp pt", "imperial pint", "imperial pints"],
            dimension: .volume,
            multiplier: Decimal(string: "0.56826125")!
        )
        add(
            ["qt", "quart", "quarts", "us qt", "us quart"],
            dimension: .volume,
            multiplier: Decimal(string: "0.946352946")!
        )
        add(
            ["imp qt", "imperial quart", "imperial quarts"],
            dimension: .volume,
            multiplier: Decimal(string: "1.1365225")!
        )
        add(
            ["gal", "gallon", "gallons", "us gal", "us gallon"],
            dimension: .volume,
            multiplier: Decimal(string: "3.785411784")!
        )
        add(
            ["imp gal", "imperial gallon", "imperial gallons"],
            dimension: .volume,
            multiplier: Decimal(string: "4.54609")!
        )

        add(
            [
                "item", "items", "unit", "units",
                "pc", "pcs", "piece", "pieces",
                "ea", "each", "ct", "count",
                "pk", "pack", "packs",
                "шт", "штук", "ед", "единиц",
                "szt", "ks", "kpl", "stk", "st", "db",
                "pz", "pezzo", "pezzi",
                "ud", "uds", "unidad", "unidades",
                "unité", "unités", "buc",
                "个", "個", "件", "개", "قطعة", "حبة", "τεμ"
            ],
            dimension: .count,
            multiplier: 1
        )

        return values
    }()

    private static let imperialVolumeOverrides: [String: Decimal] = {
        var values: [String: Decimal] = [:]

        func add(_ aliases: [String], multiplier: Decimal) {
            for alias in aliases {
                values[canonicalWord(alias)] = multiplier
            }
        }

        add(
            ["fl oz", "floz", "fluid ounce", "fluid ounces"],
            multiplier: Decimal(string: "0.0284130625")!
        )
        add(
            ["pt", "pint", "pints"],
            multiplier: Decimal(string: "0.56826125")!
        )
        add(
            ["qt", "quart", "quarts"],
            multiplier: Decimal(string: "1.1365225")!
        )
        add(
            ["gal", "gallon", "gallons"],
            multiplier: Decimal(string: "4.54609")!
        )

        return values
    }()

    static var currencyRegexAlternation: String {
        var aliases = symbolCurrencies.map(\.0)
        aliases.append(contentsOf: localeCurrencySymbols)
        aliases.append("$")
        aliases.append(contentsOf: wordCurrencyAliases.keys)
        aliases.append(contentsOf: isoCurrencyCodes)

        return Array(Set(aliases))
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
    }

    static func canonicalCurrency(
        in text: String
    ) -> String? {
        let normalized = normalizeUnicode(text)

        for (symbol, code) in symbolCurrencies
        where currencySymbolOccurs(symbol, in: normalized) {
            return code
        }

        // "$" is intentionally preserved because it can mean many currencies.
        if normalized.contains("$") {
            return "$"
        }

        for symbol in localeCurrencySymbols
        where currencySymbolOccurs(symbol, in: normalized) {
            guard let codes = localeCurrencySymbolCodes[symbol] else {
                continue
            }

            if codes.count == 1, let code = codes.first {
                return code
            }

            // Preserve shared symbols such as ¥ or kr rather than guessing.
            return symbol.uppercased()
        }

        let words = normalized
            .uppercased()
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { !$0.isEmpty }

        for word in words {
            if let alias = wordCurrencyAliases[word] {
                return alias
            }

            if word.count == 3, isoCurrencyCodes.contains(word) {
                return word
            }
        }

        return nil
    }

    static func displayCurrencyToken(
        in text: String
    ) -> String? {
        let normalized = normalizePriceText(text)

        let simpleSymbols = [
            "€", "£", "₽", "₴", "₸", "₺", "₾", "₼",
            "₹", "₩", "₫", "₪", "₱", "฿", "₦", "₡",
            "₲", "₵", "₭", "₮", "¥", "￥", "元",
            "؋", "৳", "៛"
        ]

        for symbol in simpleSymbols where normalized.contains(symbol) {
            return symbol == "￥" ? "¥" : symbol
        }

        for (symbol, code) in symbolCurrencies
        where currencySymbolOccurs(symbol, in: normalized) {
            // Composite/regional symbols are safer to show canonically.
            return code
        }

        if normalized.contains("$") {
            return "$"
        }

        for symbol in localeCurrencySymbols
        where currencySymbolOccurs(symbol, in: normalized) {
            return symbol
        }

        let words = normalized
            .uppercased()
            .components(
                separatedBy: CharacterSet.alphanumerics.inverted
            )
            .filter { !$0.isEmpty }

        for word in words {
            if word.count == 3, isoCurrencyCodes.contains(word) {
                return word
            }

            if let canonical = wordCurrencyAliases[word] {
                if word == "KM" {
                    return "KM"
                }

                if canonical == "RUB" {
                    return "₽"
                }

                return word
            }
        }

        return nil
    }

    static func displayCurrency(
        canonical: String?
    ) -> String? {
        guard let canonical else {
            return nil
        }

        switch canonical.uppercased() {
        case "EUR": return "€"
        case "GBP": return "£"
        case "RUB": return "₽"
        case "UAH": return "₴"
        case "KZT": return "₸"
        case "TRY": return "₺"
        case "GEL": return "₾"
        case "AZN": return "₼"
        case "INR": return "₹"
        case "KRW": return "₩"
        case "VND": return "₫"
        case "ILS": return "₪"
        case "PHP": return "₱"
        case "THB": return "฿"
        case "NGN": return "₦"
        case "JPY": return "¥"
        case "BAM": return "KM"
        case "$": return "$"
        default: return canonical.uppercased()
        }
    }

    static func unitDefinition(
        for raw: String,
        currencyHint: String? = nil
    ) -> UnitDefinition? {
        let key = canonicalWord(raw)

        if let currencyHint,
           canonicalCurrency(in: currencyHint) == "GBP",
           let multiplier = imperialVolumeOverrides[key] {
            return UnitDefinition(
                dimension: .volume,
                multiplier: multiplier
            )
        }

        return unitDefinitions[key]
    }

    static var unitRegexAlternation: String {
        unitDefinitions.keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
    }

    static var referenceUnitRegexAlternation: String {
        unitDefinitions
            .filter { $0.value.dimension != .count }
            .keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
    }

    static var countUnitRegexAlternation: String {
        unitDefinitions
            .filter { $0.value.dimension == .count }
            .keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
    }

    static func normalizeUnicode(
        _ text: String
    ) -> String {
        let compatibility =
            text.precomposedStringWithCompatibilityMapping

        let asciiDigits = compatibility.map { character -> String in
            if let value = character.wholeNumberValue,
               (0...9).contains(value) {
                return String(value)
            }

            return String(character)
        }
        .joined()

        return asciiDigits
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{061C}", with: "")
            .replacingOccurrences(of: "\u{2066}", with: "")
            .replacingOccurrences(of: "\u{2067}", with: "")
            .replacingOccurrences(of: "\u{2068}", with: "")
            .replacingOccurrences(of: "\u{2069}", with: "")
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: "٬", with: ",")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "х", with: "x")
    }

    static func normalizePriceText(
        _ text: String
    ) -> String {
        var normalized = normalizeUnicode(text)

        // Retail suffixes that mean "this package costs X", not quantity.
        // Examples: 99 р/шт., 99 руб./шт., 99 ₽/ед.
        let perPackagePatterns = [
            #"(?i)(?:₽|р\.?|руб\.?|rub\.?)\s*/\s*(?:шт|ед|pc|pcs|ea)\.?"#,
            #"(?i)(?:р\.?|руб\.?|rub\.?)\s*(?:за\s*)?(?:шт|ед)\.?"#
        ]

        for pattern in perPackagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(
                    normalized.startIndex...,
                    in: normalized
                )
                normalized = regex.stringByReplacingMatches(
                    in: normalized,
                    range: range,
                    withTemplate: " ₽ "
                )
            }
        }

        // Generic per-selling-unit suffixes are package-price semantics,
        // not package quantity. Example: $4.99/ea or 10 kr/st.
        let countSuffixPattern =
            #"(?i)\s*/\s*(?:"# + countUnitRegexAlternation
            + #")\.?(?![\p{L}\p{N}])"#
        if let regex = try? NSRegularExpression(
            pattern: countSuffixPattern
        ) {
            let range = NSRange(
                normalized.startIndex...,
                in: normalized
            )
            normalized = regex.stringByReplacingMatches(
                in: normalized,
                range: range,
                withTemplate: " "
            )
        }

        let rubleWordPattern =
            #"(?i)(?<![A-ZА-ЯЁ])(?:руб\.?|rub\.?|р\.)(?![A-ZА-ЯЁ])"#
        if let regex = try? NSRegularExpression(
            pattern: rubleWordPattern
        ) {
            let range = NSRange(
                normalized.startIndex...,
                in: normalized
            )
            normalized = regex.stringByReplacingMatches(
                in: normalized,
                range: range,
                withTemplate: " ₽ "
            )
        }

        return normalized
    }

    static func containsPercent(
        _ text: String
    ) -> Bool {
        normalizeUnicode(text).contains("%")
    }

    static func looksLikeReferenceUnitPrice(
        _ text: String
    ) -> Bool {
        let normalized = normalizeUnicode(text).lowercased()
        let unit = "(?:" + referenceUnitRegexAlternation + ")"

        let patterns = [
            #"(?i)/\s*(?:1\s*|10\s*|100\s*|1000\s*)?"#
                + unit + #"(?![\p{L}\p{N}])"#,
            #"(?i)(?:\bper\b|\bpro\b|\bpar\b|\bpor\b|\bje\b|за|每|لكل)\s*(?:1\s*|10\s*|100\s*|1000\s*)?"#
                + unit + #"(?![\p{L}\p{N}])"#,
            #"(?i)"# + unit + #"\s*당"#
        ]

        return patterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern))?
                .firstMatch(
                    in: normalized,
                    range: NSRange(
                        normalized.startIndex...,
                        in: normalized
                    )
                ) != nil
        }
    }

    static func looksLikePackagePriceSuffix(
        _ text: String
    ) -> Bool {
        let normalized = normalizeUnicode(text)
        let pattern =
            #"(?i)/\s*(?:"# + countUnitRegexAlternation
            + #")\.?(?![\p{L}\p{N}])"#

        return (try? NSRegularExpression(pattern: pattern))?
            .firstMatch(
                in: normalized,
                range: NSRange(normalized.startIndex..., in: normalized)
            ) != nil
    }

    static func allowsThreeFractionDigits(
        for currencyToken: String?
    ) -> Bool {
        guard let currencyToken,
              let canonical = canonicalCurrency(in: currencyToken) else {
            return false
        }

        return threeFractionCurrencyCodes.contains(canonical)
    }

    private static func currencySymbolOccurs(
        _ symbol: String,
        in text: String
    ) -> Bool {
        guard !symbol.isEmpty else {
            return false
        }

        var pattern = NSRegularExpression.escapedPattern(for: symbol)

        if let first = symbol.first,
           first.isLetter || first.isNumber {
            pattern = #"(?<![\p{L}\p{N}])"# + pattern
        }

        if let last = symbol.last,
           last.isLetter || last.isNumber {
            pattern += #"(?![\p{L}\p{N}])"#
        }

        return (try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ))?
        .firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) != nil
    }

    private static func canonicalWord(
        _ value: String
    ) -> String {
        normalizeUnicode(value)
            .lowercased()
            .trimmingCharacters(
                in: CharacterSet.alphanumerics.inverted
            )
    }
}
