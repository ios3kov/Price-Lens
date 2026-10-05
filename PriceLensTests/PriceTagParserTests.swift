import CoreGraphics
import XCTest
#if canImport(PriceLensCore)
@testable import PriceLensCore
#else
@testable import PriceLens
#endif

final class PriceTagParserTests: XCTestCase {
    func testParsesPriceAndGrams() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "4.99"))
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
        XCTAssertEqual(candidate.dimension, .mass)
        XCTAssertEqual(candidate.unitPrice, Decimal(string: "9.98"))
    }

    func testParsesPriceSplitIntoWholeAndCentsOCRItems() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4", x: 20, y: 20, width: 58, height: 52),
                    item("99 €", x: 82, y: 24, width: 46, height: 30),
                    item("500 g", x: 20, y: 82, width: 120, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "4.99"))
        XCTAssertEqual(candidate.currencyToken, "€")
        XCTAssertEqual(candidate.unitPrice, Decimal(string: "9.98"))
    }

    func testRejectsDistantWholeAndCentsFragments() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("4", x: 20, y: 20, width: 58, height: 52),
                item("99", x: 260, y: 20, width: 44, height: 30),
                item("500 g", x: 20, y: 82, width: 120, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testParsesCommaDecimalAndLiters() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("2,80 €", x: 20, y: 20, height: 44),
                    item("750 ml", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "2.80"))
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.75"))
        XCTAssertEqual(candidate.dimension, .volume)
        XCTAssertEqual(candidate.currencyToken, "€")
    }

    func testParsesMultipack() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("8.00", x: 20, y: 20, height: 44),
                    item("6 × 330 ml", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "1.98"))
        XCTAssertEqual(candidate.dimension, .volume)
    }

    func testRejectsBareDecimalQuantityAsItsOwnPrice() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("1.50 L", x: 20, y: 20, height: 30)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testAllowsPriceAndQuantityOnOneLineWhenCurrencyIsExplicit() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("€1.99 500 ml", x: 20, y: 20, height: 34)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1.99"))
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
        XCTAssertEqual(candidate.dimension, .volume)
        XCTAssertEqual(candidate.currencyToken, "€")
    }

    func testFindsCurrencyOnNeighboringOCRLine() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1.99", x: 20, y: 20, height: 44),
                    item("€", x: 120, y: 20, height: 20),
                    item("500 ml", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.currencyToken, "€")
    }

    func testParsesItemsCount() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("8.00", x: 20, y: 20, height: 44),
                    item("10 items", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(10))
        XCTAssertEqual(candidate.dimension, .count)
    }

    func testPrefersPackagePriceOverUnitPriceLine() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("7.99 / kg", x: 20, y: 10, height: 18),
                    item("4.99", x: 20, y: 35, height: 44),
                    item("500 g", x: 20, y: 85, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "4.99"))
    }

    func testComparisonChoosesCheaperMassProduct() throws {
        let left = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        let right = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("7.49", x: 240, y: 20, height: 44),
                    item("1 kg", x: 240, y: 70, height: 24)
                ]
            )
        )

        let result = ComparisonEngine.compare(left: left, right: right)
        let comparison = try XCTUnwrap(try? result.get())

        XCTAssertEqual(comparison.winner, .right)
        XCTAssertEqual(comparison.roundedPercent, 25)
        XCTAssertEqual(comparison.headline, "B is 25% cheaper per kg")
    }

    func testRejectsMixedDimensions() throws {
        let mass = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        let volume = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 240, y: 20, height: 44),
                    item("500 ml", x: 240, y: 70, height: 24)
                ]
            )
        )

        switch ComparisonEngine.compare(left: mass, right: volume) {
        case .failure(.incompatibleDimensions):
            break
        default:
            XCTFail("Expected incompatible dimensions")
        }
    }

    func testClustererKeepsTwoNearbyTagsSeparate() {
        let items = [
            item("4.99", x: 20, y: 20, height: 40),
            item("500 g", x: 20, y: 68, height: 22),
            item("7.49", x: 170, y: 20, height: 40),
            item("1 kg", x: 170, y: 68, height: 22)
        ]

        let clusters = TagClusterer.clusters(from: items)
        let candidates = clusters.compactMap(PriceTagParser.parse(cluster:))

        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(candidates.count, 2)
    }

    func testClustererSplitsVerticallyStackedTags() {
        let items = [
            item("4.99", x: 30, y: 20, height: 40),
            item("500 g", x: 30, y: 68, height: 22),
            item("7.49", x: 32, y: 130, height: 40),
            item("1 kg", x: 32, y: 178, height: 22)
        ]

        let clusters = TagClusterer.clusters(from: items)
        let candidates = clusters.compactMap(PriceTagParser.parse(cluster:))

        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(candidates.count, 2)

        let prices = Set(candidates.map { NSDecimalNumber(decimal: $0.price).stringValue })
        XCTAssertEqual(prices, Set(["4.99", "7.49"]))
    }

    func testEqualUnitPricesProduceNoWinner() throws {
        let first = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("2.00", x: 20, y: 20, height: 40),
                    item("500 g", x: 20, y: 68, height: 22)
                ]
            )
        )
        let second = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.00", x: 220, y: 20, height: 40),
                    item("1 kg", x: 220, y: 68, height: 22)
                ]
            )
        )

        let comparison = try XCTUnwrap(
            try? ComparisonEngine.compare(left: first, right: second).get()
        )

        XCTAssertEqual(comparison.winner, .equal)
        XCTAssertEqual(comparison.cheaperPercent, 0)
    }

    func testRejectsDifferentExplicitCurrencies() throws {
        let first = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("€2.00", x: 20, y: 20, height: 40),
                    item("500 g", x: 20, y: 68, height: 22)
                ]
            )
        )
        let second = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("$2.00", x: 220, y: 20, height: 40),
                    item("500 g", x: 220, y: 68, height: 22)
                ]
            )
        )

        switch ComparisonEngine.compare(left: first, right: second) {
        case .failure(.differentCurrencies):
            break
        default:
            XCTFail("Expected different currencies")
        }
    }

    private func item(
        _ transcript: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 130,
        height: CGFloat
    ) -> ScannedText {
        ScannedText(
            id: UUID(),
            transcript: transcript,
            bounds: CGRect(x: x, y: y, width: width, height: height),
            confidence: 0.95
        )
    }
}
