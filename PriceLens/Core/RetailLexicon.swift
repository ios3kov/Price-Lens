import Foundation

enum RetailLexicon {
    struct UnitDefinition: Equatable {
        let dimension: QuantityDimension
        /// Multiplier into Price Lens base units: kg, L or item.
        let multiplier: Decimal
    }

    private static let isoCurrencyCodes = Set(
        Locale.commonISOCurrencyCodes.map { $0.uppercased() }
    )

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
        ("¥", "JPY"),
        ("￥", "JPY"),
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
            [
                "item", "items", "pc", "pcs", "piece", "pieces",
                "ea", "each", "ct", "count", "шт", "штук", "ед", "единиц",
                "个", "個", "件", "개", "قطعة"
            ],
            dimension: .count,
            multiplier: 1
        )

        return values
    }()

    static var currencyRegexAlternation: String {
        var aliases = symbolCurrencies.map(\.0)
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
        where normalized.localizedCaseInsensitiveContains(symbol) {
            return code
        }

        // "$" is intentionally preserved because it can mean many currencies.
        if normalized.contains("$") {
            return "$"
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
        for raw: String
    ) -> UnitDefinition? {
        unitDefinitions[canonicalWord(raw)]
    }

    static var unitRegexAlternation: String {
        unitDefinitions.keys
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
        let compact = normalizeUnicode(text)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        let patterns = [
            "/kg", "/кг", "/g", "/г",
            "/l", "/л", "/ml", "/мл",
            "/100g", "/100г", "/100ml", "/100мл",
            "perkg", "per100g", "per100ml",
            "за1кг", "закг", "за100г", "за100мл"
        ]

        return patterns.contains(where: compact.contains)
    }

    static func looksLikePackagePriceSuffix(
        _ text: String
    ) -> Bool {
        let normalized = normalizeUnicode(text)
        let pattern =
            #"(?i)(?:₽|р\.?|руб\.?|rub\.?)\s*/\s*(?:шт|ед|pc|pcs|ea)\.?"#
        return (try? NSRegularExpression(pattern: pattern))?
            .firstMatch(
                in: normalized,
                range: NSRange(normalized.startIndex..., in: normalized)
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
