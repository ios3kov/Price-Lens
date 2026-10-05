import CoreGraphics
import XCTest
#if canImport(PriceLensCore)
@testable import PriceLensCore
#else
@testable import PriceLens
#endif

final class PriceTagParserTests: XCTestCase {
    func testDropoutGraceGateSchedulesOnlyOnceUntilCompleted() throws {
        var gate = DropoutGraceGate()

        let generation = try XCTUnwrap(gate.begin())
        XCTAssertNil(gate.begin())
        XCTAssertTrue(gate.isPending)

        XCTAssertTrue(gate.complete(generation: generation))
        XCTAssertFalse(gate.isPending)
        XCTAssertNotNil(gate.begin())
    }

    func testDropoutGraceGateCancellationInvalidatesPendingGeneration() throws {
        var gate = DropoutGraceGate()

        let generation = try XCTUnwrap(gate.begin())
        gate.cancel()

        XCTAssertFalse(gate.complete(generation: generation))
        XCTAssertFalse(gate.isPending)
    }

    func testDeduplicatorCollapsesSameCandidateInSameArea() {
        let first = productCandidate(
            price: "4.99",
            quantity: "0.5",
            bounds: CGRect(x: 20, y: 20, width: 120, height: 70),
            confidence: 0.95
        )
        let duplicate = productCandidate(
            price: "4.99",
            quantity: "0.5",
            bounds: CGRect(x: 24, y: 25, width: 118, height: 68),
            confidence: 0.80
        )

        let output = CandidateDeduplicator.deduplicated([duplicate, first])

        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output.first?.confidence, 0.95)
    }

    func testDeduplicatorKeepsIdenticalProductsWhenSpatiallySeparate() {
        let top = productCandidate(
            price: "4.99",
            quantity: "0.5",
            bounds: CGRect(x: 40, y: 20, width: 120, height: 70),
            confidence: 0.95
        )
        let bottom = productCandidate(
            price: "4.99",
            quantity: "0.5",
            bounds: CGRect(x: 42, y: 180, width: 120, height: 70),
            confidence: 0.92
        )

        let output = CandidateDeduplicator.deduplicated([top, bottom])

        XCTAssertEqual(output.count, 2)
    }

    func testDeduplicatorKeepsDifferentCandidatesEvenWhenOverlapping() {
        let first = productCandidate(
            price: "4.99",
            quantity: "0.5",
            bounds: CGRect(x: 20, y: 20, width: 120, height: 70)
        )
        let second = productCandidate(
            price: "5.99",
            quantity: "0.5",
            bounds: CGRect(x: 24, y: 24, width: 120, height: 70)
        )

        let output = CandidateDeduplicator.deduplicated([first, second])

        XCTAssertEqual(output.count, 2)
    }

    func testRecognitionStabilizerRequiresContinuousTime() {
        var stabilizer = RecognitionStabilizer(requiredDuration: 0.35)

        XCTAssertFalse(stabilizer.observe(signature: "A|B", at: 10.00))
        XCTAssertFalse(stabilizer.observe(signature: "A|B", at: 10.20))
        XCTAssertTrue(stabilizer.observe(signature: "A|B", at: 10.36))
    }

    func testRecognitionStabilizerResetsWhenResultChanges() {
        var stabilizer = RecognitionStabilizer(requiredDuration: 0.35)

        XCTAssertFalse(stabilizer.observe(signature: "A|B", at: 10.00))
        XCTAssertFalse(stabilizer.observe(signature: "A|C", at: 10.30))
        XCTAssertFalse(stabilizer.observe(signature: "A|C", at: 10.50))
        XCTAssertTrue(stabilizer.observe(signature: "A|C", at: 10.66))

        stabilizer.reset()
        XCTAssertFalse(stabilizer.observe(signature: "A|C", at: 20.00))
    }

    func testScanRegionLeavesSpaceForTopAndBottomUI() throws {
        let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
        let region = try XCTUnwrap(ScanRegionLayout.rect(in: bounds))

        XCTAssertGreaterThan(region.minX, bounds.minX)
        XCTAssertGreaterThan(region.minY, bounds.minY)
        XCTAssertLessThan(region.maxX, bounds.maxX)
        XCTAssertLessThan(region.maxY, bounds.maxY)
        XCTAssertEqual(region.width, 327.6, accuracy: 0.01)
        XCTAssertEqual(region.height, 270.08, accuracy: 0.01)
    }

    func testScanRegionRejectsEmptyBounds() {
        XCTAssertNil(ScanRegionLayout.rect(in: .zero))
    }

    func testSupportedParserCorpus() throws {
        struct Case {
            let name: String
            let price: String
            let quantity: String
            let expectedPrice: String
            let expectedQuantity: String
            let dimension: QuantityDimension
        }

        let cases: [Case] = [
            .init(name: "compact grams", price: "1.99", quantity: "250g", expectedPrice: "1.99", expectedQuantity: "0.25", dimension: .mass),
            .init(name: "comma grams", price: "3,49 €", quantity: "750 g", expectedPrice: "3.49", expectedQuantity: "0.75", dimension: .mass),
            .init(name: "kilograms", price: "4,50 BAM", quantity: "1,5 kg", expectedPrice: "4.50", expectedQuantity: "1.5", dimension: .mass),
            .init(name: "milliliters", price: "2.10", quantity: "500 ml", expectedPrice: "2.10", expectedQuantity: "0.5", dimension: .volume),
            .init(name: "centiliters", price: "2,80 €", quantity: "75 cl", expectedPrice: "2.80", expectedQuantity: "0.75", dimension: .volume),
            .init(name: "liters cyrillic", price: "5.25", quantity: "1,5 л", expectedPrice: "5.25", expectedQuantity: "1.5", dimension: .volume),
            .init(name: "multipack mass", price: "6.99", quantity: "4x250g", expectedPrice: "6.99", expectedQuantity: "1", dimension: .mass),
            .init(name: "multipack volume", price: "8.00", quantity: "6 x 330 ml", expectedPrice: "8.00", expectedQuantity: "1.98", dimension: .volume),
            .init(name: "pieces", price: "6.00", quantity: "6 pcs", expectedPrice: "6.00", expectedQuantity: "6", dimension: .count),
            .init(name: "pieces cyrillic", price: "8.00", quantity: "10 шт", expectedPrice: "8.00", expectedQuantity: "10", dimension: .count),
            .init(name: "items", price: "9.99", quantity: "12 items", expectedPrice: "9.99", expectedQuantity: "12", dimension: .count)
        ]

        for testCase in cases {
            try XCTContext.runActivity(named: testCase.name) { _ in
                let candidate = try XCTUnwrap(
                    PriceTagParser.parse(
                        cluster: [
                            item(testCase.price, x: 20, y: 20, height: 44),
                            item(testCase.quantity, x: 20, y: 70, height: 24)
                        ]
                    )
                )

                XCTAssertEqual(
                    NSDecimalNumber(decimal: candidate.price).stringValue,
                    NSDecimalNumber(decimal: Decimal(string: testCase.expectedPrice)!).stringValue
                )
                XCTAssertEqual(
                    NSDecimalNumber(decimal: candidate.normalizedQuantity).stringValue,
                    NSDecimalNumber(decimal: Decimal(string: testCase.expectedQuantity)!).stringValue
                )
                XCTAssertEqual(candidate.dimension, testCase.dimension)
            }
        }
    }

    func testUnsafeParserCorpusIsRejected() {
        let cases: [[ScannedText]] = [
            [item("4.99", x: 20, y: 20, height: 44)],
            [item("500 g", x: 20, y: 20, height: 24)],
            [
                item("7.99 / kg", x: 20, y: 20, height: 18),
                item("500 g", x: 20, y: 55, height: 24)
            ],
            [item("1.50 L", x: 20, y: 20, height: 30)]
        ]

        for cluster in cases {
            XCTAssertNil(PriceTagParser.parse(cluster: cluster))
        }
    }

    func testCurrencyCodeRequiresTokenBoundary() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("BAMBOO 4.99", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertNil(candidate.currencyToken)
    }

    func testRecognizesStandaloneBAMCurrencyCode() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99 BAM", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.currencyToken, "BAM")
    }

    func testRecognizesStandaloneKMCurrencyCode() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99 KM", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.currencyToken, "KM")
    }

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

    func testParsesGroupedEuropeanDecimalPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1.299,99 €", x: 20, y: 20, height: 44),
                    item("1 kg", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1299.99"))
    }

    func testParsesSpaceGroupedDecimalPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1 299,99 €", x: 20, y: 20, height: 44),
                    item("1 kg", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1299.99"))
    }

    func testParsesNBSPGroupedDecimalPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1\u{00A0}299,99 €", x: 20, y: 20, height: 44),
                    item("1 kg", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1299.99"))
    }

    func testParsesNarrowNBSPGroupedDecimalPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1\u{202F}299,99 €", x: 20, y: 20, height: 44),
                    item("1 kg", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1299.99"))
    }

    func testParsesUSGroupedDecimalPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("$1,299.99", x: 20, y: 20, height: 44),
                    item("1 item", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1299.99"))
    }

    func testParsesGroupedZeroCentsPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1.299,- €", x: 20, y: 20, height: 44),
                    item("1 item", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(1299))
    }

    func testParsesGroupedIntegerCurrencyPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("1 299 €", x: 20, y: 20, height: 44),
                    item("1 item", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(1299))
    }

    func testParsesIntegerPriceWithNearbyCurrencyFragment() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4", x: 20, y: 20, width: 54, height: 44),
                    item("€", x: 80, y: 30, width: 24, height: 22),
                    item("500 g", x: 20, y: 78, width: 120, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(4))
        XCTAssertEqual(candidate.currencyToken, "€")
    }

    func testRepairsMissingDecimalSeparatorWithCurrency() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4 99 €", x: 20, y: 20, width: 120, height: 44),
                    item("500 g", x: 20, y: 76, width: 120, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "4.99"))
    }

    func testRepairsMissingDecimalSeparatorWithNearbyCurrency() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4 99", x: 20, y: 20, width: 92, height: 44),
                    item("€", x: 116, y: 30, width: 24, height: 22),
                    item("500 g", x: 20, y: 76, width: 120, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "4.99"))
    }

    func testNearbyCurrencyDoesNotTurnQuantityLineIntoPrice() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("1.50 L", x: 20, y: 20, width: 100, height: 34),
                item("€", x: 126, y: 28, width: 24, height: 22),
                item("500 g", x: 20, y: 72, width: 120, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testPriceLineWithCurrencyIsNotUsedAsNearbyCurrencyMarker() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("4", x: 20, y: 20, width: 50, height: 44),
                item("€7.99", x: 76, y: 22, width: 72, height: 34),
                item("500 g", x: 20, y: 76, width: 120, height: 24)
            ]
        )

        XCTAssertEqual(candidate?.price, Decimal(string: "7.99"))
    }

    func testRejectsMissingDecimalSeparatorWithoutCurrency() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("4 99", x: 20, y: 20, width: 92, height: 44),
                item("500 g", x: 20, y: 76, width: 120, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testParsesIntegerPriceWithSuffixCurrency() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4 €", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(4))
        XCTAssertEqual(candidate.currencyToken, "€")
    }

    func testParsesIntegerPriceWithPrefixCurrency() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("€ 4", x: 20, y: 20, height: 44),
                    item("1 kg", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(4))
    }

    func testParsesEuropeanZeroCentsPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4,- €", x: 20, y: 20, height: 44),
                    item("500 ml", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(4))
        XCTAssertEqual(candidate.dimension, .volume)
    }

    func testParsesEnDashZeroCentsWithoutCurrency() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.–", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(4))
    }

    func testIntegerCurrencyPriceUsesNumberAdjacentToCurrency() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("500 ml €4", x: 20, y: 20, height: 34)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(4))
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
    }

    func testRejectsBareIntegerPriceWithoutCentsOrCurrency() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("4", x: 20, y: 20, height: 44),
                item("500 g", x: 20, y: 70, height: 24)
            ]
        )

        XCTAssertNil(candidate)
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

    func testRejectsSameSizeNumericFragmentsAsSplitPriceWithoutCurrency() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("4", x: 20, y: 20, width: 58, height: 40),
                item("99", x: 82, y: 20, width: 46, height: 40),
                item("500 g", x: 20, y: 72, width: 120, height: 24)
            ]
        )

        XCTAssertNil(candidate)
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

    func testParsesSpaceGroupedGrams() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("1 000 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(1))
        XCTAssertEqual(candidate.dimension, .mass)
    }

    func testTreatsThreeDigitSeparatorAsGroupingForGrams() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("1.500 g", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "1.5"))
    }

    func testTreatsThreeDigitSeparatorAsGroupingForMilliliters() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("1,500 ml", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "1.5"))
        XCTAssertEqual(candidate.dimension, .volume)
    }

    func testKeepsThreeDigitDecimalForLiters() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 20, height: 44),
                    item("1.500 L", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "1.5"))
    }

    func testParsesGroupedMultipackSize() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("8.00", x: 20, y: 20, height: 44),
                    item("2 × 1.500 ml", x: 20, y: 70, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(3))
        XCTAssertEqual(candidate.dimension, .volume)
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

    func testRejectsCurrencyUnitPriceAsPackagePrice() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("€7.99 / kg", x: 20, y: 20, height: 22),
                item("500 g", x: 20, y: 58, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testRejectsQuantityLikeDecimalAsPriceWhenOtherQuantityExists() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("1.50 L", x: 20, y: 20, height: 30),
                item("500 g", x: 20, y: 64, height: 24)
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

    func testRejectsPer100GramUnitPriceAsPackagePrice() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("€1.99 per 100 g", x: 20, y: 20, height: 22),
                item("500 g", x: 20, y: 58, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testRejectsPer100MilliliterUnitPriceAsPackagePrice() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("1,49 € per 100 ml", x: 20, y: 20, height: 22),
                item("750 ml", x: 20, y: 58, height: 24)
            ]
        )

        XCTAssertNil(candidate)
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

    func testClustererRecursivelySeparatesThreeMergedTags() {
        let items = [
            item("1.99", x: 10, y: 20, width: 80, height: 38),
            item("250 g", x: 10, y: 64, width: 80, height: 22),

            item("2.99", x: 105, y: 20, width: 80, height: 38),
            item("500 g", x: 105, y: 64, width: 80, height: 22),

            item("4.99", x: 200, y: 20, width: 80, height: 38),
            item("1 kg", x: 200, y: 64, width: 80, height: 22)
        ]

        let clusters = TagClusterer.clusters(from: items)
        let candidates = clusters.compactMap(PriceTagParser.parse(cluster:))

        XCTAssertEqual(clusters.count, 3)
        XCTAssertEqual(candidates.count, 3)

        let prices = Set(
            candidates.map {
                NSDecimalNumber(decimal: $0.price).stringValue
            }
        )
        XCTAssertEqual(prices, Set(["1.99", "2.99", "4.99"]))
    }

    func testClustererRecursivelySeparatesFourMergedTags() {
        let items = [
            item("1.99", x: 10, y: 20, width: 72, height: 38),
            item("250 g", x: 10, y: 64, width: 72, height: 22),

            item("2.99", x: 92, y: 20, width: 72, height: 38),
            item("500 g", x: 92, y: 64, width: 72, height: 22),

            item("3.99", x: 174, y: 20, width: 72, height: 38),
            item("750 g", x: 174, y: 64, width: 72, height: 22),

            item("4.99", x: 256, y: 20, width: 72, height: 38),
            item("1 kg", x: 256, y: 64, width: 72, height: 22)
        ]

        let clusters = TagClusterer.clusters(from: items)
        let candidates = clusters.compactMap(PriceTagParser.parse(cluster:))

        XCTAssertEqual(clusters.count, 4)
        XCTAssertEqual(candidates.count, 4)
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

    func testCandidateOrderingUsesHorizontalAxisForSideBySideTags() throws {
        let left = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 20, y: 40, height: 40),
                    item("500 g", x: 20, y: 88, height: 22)
                ]
            )
        )
        let right = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("7.49", x: 240, y: 20, height: 40),
                    item("1 kg", x: 240, y: 68, height: 22)
                ]
            )
        )

        let ordered = CandidateOrdering.ordered([right, left])

        XCTAssertEqual(ordered.first?.price, Decimal(string: "4.99"))
        XCTAssertEqual(ordered.last?.price, Decimal(string: "7.49"))
    }

    func testCandidateOrderingUsesVerticalAxisForStackedTags() throws {
        let top = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("4.99", x: 40, y: 20, height: 40),
                    item("500 g", x: 40, y: 68, height: 22)
                ]
            )
        )
        let bottom = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("7.49", x: 20, y: 240, height: 40),
                    item("1 kg", x: 20, y: 288, height: 22)
                ]
            )
        )

        let ordered = CandidateOrdering.ordered([bottom, top])

        XCTAssertEqual(ordered.first?.price, Decimal(string: "4.99"))
        XCTAssertEqual(ordered.last?.price, Decimal(string: "7.49"))
    }

    func testParsesRussianRubleSplitShelfPriceWithOldPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("-15% СКИДКА", x: 10, y: 10, width: 90, height: 24),
                    item("ПЕЧЕНЬЕ ШОКОЛАЙТ", x: 120, y: 14, width: 180, height: 22),
                    item("200Г ОРЕХ, КРЕМ С ФРУКТОВОЙ", x: 120, y: 42, width: 230, height: 22),
                    item("Без карты", x: 110, y: 82, width: 90, height: 18),
                    item("269", x: 205, y: 78, width: 58, height: 30),
                    item("99", x: 266, y: 82, width: 24, height: 16),
                    item("229", x: 145, y: 118, width: 150, height: 82),
                    item("99₽", x: 300, y: 145, width: 48, height: 34),
                    item("ШТ", x: 306, y: 188, width: 36, height: 20)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "229.99"))
        XCTAssertEqual(candidate.currencyToken, "₽")
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.2"))
        XCTAssertEqual(candidate.dimension, .mass)
    }

    func testParsesRussianRubleDecimalPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("229,99 ₽", x: 20, y: 20, width: 150, height: 50),
                    item("200 г", x: 20, y: 80, width: 90, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "229.99"))
        XCTAssertEqual(candidate.currencyToken, "₽")
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.2"))
    }

    func testRubleSymbolAndCodeAreSameCurrency() throws {
        let symbol = ProductCandidate(
            id: UUID(),
            price: Decimal(string: "229.99")!,
            currencyToken: "₽",
            normalizedQuantity: Decimal(string: "0.2")!,
            dimension: .mass,
            sourceBounds: .zero,
            confidence: 0.9,
            rawText: ""
        )
        let code = ProductCandidate(
            id: UUID(),
            price: Decimal(string: "799")!,
            currencyToken: "RUB",
            normalizedQuantity: Decimal(string: "1")!,
            dimension: .mass,
            sourceBounds: .zero,
            confidence: 0.9,
            rawText: ""
        )

        let comparison = try ComparisonEngine.compare(
            left: symbol,
            right: code
        ).get()

        XCTAssertEqual(comparison.winner, .right)
    }

    func testUniversalCurrencyLexiconRecognizesCommonGlobalForms() {
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "€ 4,99"), "EUR")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "R$ 12,90"), "BRL")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "₹99"), "INR")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "₴ 120"), "UAH")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "₸ 999"), "KZT")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "CHF 4.95"), "CHF")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "PLN 9,99"), "PLN")
        XCTAssertEqual(RetailLexicon.canonicalCurrency(in: "229 руб."), "RUB")
    }

    func testParsesBrazilianRealPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("R$ 12,90", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 72, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "12.90"))
        XCTAssertEqual(candidate.currencyToken, "BRL")
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
    }

    func testParsesSwissFrancPriceByISOCode() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("CHF 4.95", x: 20, y: 20, height: 44),
                    item("250 g", x: 20, y: 72, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "4.95"))
        XCTAssertEqual(candidate.currencyToken, "CHF")
    }

    func testParsesIndianRupeeIntegerPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("₹99", x: 20, y: 20, height: 44),
                    item("500 g", x: 20, y: 72, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(99))
        XCTAssertEqual(candidate.currencyToken, "₹")
    }

    func testParsesRussianPerItemSplitPrice() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("СМЕТАНА ПРОСТОКВАШИНО", x: 20, y: 10, width: 240, height: 24),
                    item("315г", x: 20, y: 40, width: 72, height: 22),
                    item("78", x: 315, y: 14, width: 42, height: 24),
                    item("99", x: 360, y: 18, width: 22, height: 14),
                    item("56", x: 165, y: 84, width: 120, height: 88),
                    item("99 р/шт.", x: 290, y: 105, width: 96, height: 34)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "56.99"))
        XCTAssertEqual(candidate.currencyToken, "₽")
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.315"))
        XCTAssertEqual(candidate.dimension, .mass)
    }

    func testParsesPoundsAndOuncesToKilograms() throws {
        let pound = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("$4.99", x: 20, y: 20, height: 44),
                    item("1 lb", x: 20, y: 72, height: 24)
                ]
            )
        )
        let ounces = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("$4.99", x: 20, y: 20, height: 44),
                    item("16 oz", x: 20, y: 72, height: 24)
                ]
            )
        )

        XCTAssertEqual(
            pound.normalizedQuantity,
            Decimal(string: "0.45359237")
        )
        XCTAssertEqual(
            ounces.normalizedQuantity,
            Decimal(string: "0.45359237")
        )
    }

    func testParsesDecilitersAndCountAliases() throws {
        let volume = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("€1.99", x: 20, y: 20, height: 44),
                    item("5 dl", x: 20, y: 72, height: 24)
                ]
            )
        )
        let count = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("$2.99", x: 20, y: 20, height: 44),
                    item("6 ea", x: 20, y: 72, height: 24)
                ]
            )
        )

        XCTAssertEqual(volume.normalizedQuantity, Decimal(string: "0.5"))
        XCTAssertEqual(volume.dimension, .volume)
        XCTAssertEqual(count.normalizedQuantity, Decimal(6))
        XCTAssertEqual(count.dimension, .count)
    }

    func testUnicodeMultipackNormalization() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("€3.99", x: 20, y: 20, height: 44),
                    item("2×500 мл", x: 20, y: 72, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.normalizedQuantity, Decimal(1))
        XCTAssertEqual(candidate.dimension, .volume)
    }

    func testRejectsReferenceUnitPriceInRussian() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("1149 ₽/кг", x: 20, y: 20, height: 22),
                item("315 г", x: 20, y: 58, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testRejectsAmbiguousSimilarPromotionalPrices() {
        let candidate = PriceTagParser.parse(
            cluster: [
                item("€4.99", x: 20, y: 20, width: 100, height: 42),
                item("€5.09", x: 140, y: 20, width: 100, height: 42),
                item("500 g", x: 20, y: 78, width: 100, height: 24)
            ]
        )

        XCTAssertNil(candidate)
    }

    func testParsesArabicIndicDigitsAndSeparators() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("د.إ ١٢٫٥٠", x: 20, y: 20, width: 150, height: 44),
                    item("٥٠٠ g", x: 20, y: 72, width: 100, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "12.50"))
        XCTAssertEqual(candidate.currencyToken, "AED")
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
    }

    func testParsesIndianGrouping() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("₹1,29,999.00", x: 20, y: 20, width: 190, height: 44),
                    item("1 kg", x: 20, y: 72, width: 100, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "129999.00"))
        XCTAssertEqual(candidate.currencyToken, "₹")
    }

    func testParsesApostropheGrouping() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("CHF 1’299.95", x: 20, y: 20, width: 190, height: 44),
                    item("1 kg", x: 20, y: 72, width: 100, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "1299.95"))
        XCTAssertEqual(candidate.currencyToken, "CHF")
    }

    func testParsesCurrencyAsDecimalSeparator() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("12€50", x: 20, y: 20, width: 120, height: 44),
                    item("500 g", x: 20, y: 72, width: 100, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "12.50"))
        XCTAssertEqual(candidate.currencyToken, "€")
    }

    func testParsesChineseMassUnit() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("¥99", x: 20, y: 20, width: 100, height: 44),
                    item("500 克", x: 20, y: 72, width: 100, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(99))
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
        XCTAssertEqual(candidate.dimension, .mass)
    }

    func testParsesArabicMassUnit() throws {
        let candidate = try XCTUnwrap(
            PriceTagParser.parse(
                cluster: [
                    item("ر.س 12.50", x: 20, y: 20, width: 140, height: 44),
                    item("500 غ", x: 20, y: 72, width: 100, height: 24)
                ]
            )
        )

        XCTAssertEqual(candidate.price, Decimal(string: "12.50"))
        XCTAssertEqual(candidate.currencyToken, "SAR")
        XCTAssertEqual(candidate.normalizedQuantity, Decimal(string: "0.5"))
    }

    func testCandidateExtractorFallsBackToWholeSingleLabelROI() throws {
        let items = [
            item(
                "315г",
                x: 24,
                y: 24,
                width: 70,
                height: 22
            ),
            item(
                "56",
                x: 180,
                y: 110,
                width: 120,
                height: 88
            ),
            item(
                "99",
                x: 304,
                y: 130,
                width: 42,
                height: 32
            ),
            item(
                "р/шт.",
                x: 350,
                y: 142,
                width: 72,
                height: 24
            )
        ]

        XCTAssertGreaterThan(
            TagClusterer.clusters(from: items).count,
            1
        )

        let candidates = CandidateExtractor.candidates(
            from: items
        )

        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(
            candidate.price,
            Decimal(string: "56.99")
        )
        XCTAssertEqual(candidate.currencyToken, "₽")
        XCTAssertEqual(
            candidate.normalizedQuantity,
            Decimal(string: "0.315")
        )
    }

    func testCandidateExtractorHandlesSeparateCurrencySuffixFragment() throws {
        let items = [
            item(
                "315г",
                x: 18,
                y: 18,
                width: 74,
                height: 22
            ),
            item(
                "78",
                x: 320,
                y: 20,
                width: 42,
                height: 24
            ),
            item(
                "99",
                x: 365,
                y: 24,
                width: 22,
                height: 14
            ),
            item(
                "56",
                x: 165,
                y: 86,
                width: 120,
                height: 88
            ),
            item(
                "99",
                x: 292,
                y: 108,
                width: 40,
                height: 30
            ),
            item(
                "р/шт.",
                x: 336,
                y: 118,
                width: 76,
                height: 22
            )
        ]

        let candidate = try XCTUnwrap(
            CandidateExtractor.candidates(
                from: items
            ).first
        )

        XCTAssertEqual(
            candidate.price,
            Decimal(string: "56.99")
        )
        XCTAssertEqual(candidate.currencyToken, "₽")
        XCTAssertEqual(
            candidate.normalizedQuantity,
            Decimal(string: "0.315")
        )
    }

    func testCandidateExtractorDoesNotCollapseTwoCompleteLabels() {
        let items = [
            item(
                "€4.99",
                x: 10,
                y: 20,
                width: 90,
                height: 40
            ),
            item(
                "500 g",
                x: 10,
                y: 68,
                width: 90,
                height: 22
            ),
            item(
                "€7.49",
                x: 240,
                y: 20,
                width: 90,
                height: 40
            ),
            item(
                "1 kg",
                x: 240,
                y: 68,
                width: 90,
                height: 22
            )
        ]

        let candidates = CandidateExtractor.candidates(
            from: items
        )

        XCTAssertEqual(candidates.count, 2)
    }

    func testComparisonSessionAddsAndRanksMultipleItems() {
        var session = ComparisonSession()

        let first = productCandidate(
            price: "4.99",
            quantity: "0.50",
            bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
        )
        let second = productCandidate(
            price: "7.49",
            quantity: "1.00",
            bounds: CGRect(x: 110, y: 10, width: 80, height: 60)
        )
        let third = productCandidate(
            price: "8.10",
            quantity: "1.00",
            bounds: CGRect(x: 210, y: 10, width: 80, height: 60)
        )

        XCTAssertNoThrow(try session.add(first).get())
        XCTAssertNoThrow(try session.add(second).get())
        XCTAssertNoThrow(try session.add(third).get())

        XCTAssertEqual(session.items.count, 3)
        XCTAssertEqual(
            session.rankedItems.map(\.price),
            [
                Decimal(string: "7.49")!,
                Decimal(string: "8.10")!,
                Decimal(string: "4.99")!
            ]
        )
        XCTAssertEqual(
            session.bestItem?.price,
            Decimal(string: "7.49")
        )
    }

    func testComparisonSessionRejectsDuplicate() throws {
        var session = ComparisonSession()
        let candidate = productCandidate(
            price: "4.99",
            quantity: "0.50",
            bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
        )

        try session.add(candidate).get()

        if case .failure(.duplicate) = session.add(candidate) {
            // Expected.
        } else {
            XCTFail("Expected duplicate rejection")
        }
    }

    func testComparisonSessionRejectsMixedDimensions() throws {
        var session = ComparisonSession()
        let mass = productCandidate(
            price: "4.99",
            quantity: "0.50",
            bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
        )
        let volume = ProductCandidate(
            id: UUID(),
            price: Decimal(string: "2.99")!,
            currencyToken: "€",
            normalizedQuantity: Decimal(string: "0.75")!,
            dimension: .volume,
            sourceBounds: CGRect(x: 110, y: 10, width: 80, height: 60),
            confidence: 0.9,
            rawText: ""
        )

        try session.add(mass).get()

        if case .failure(.incompatibleDimensions) = session.add(volume) {
            // Expected.
        } else {
            XCTFail("Expected incompatible dimension rejection")
        }
    }

    func testComparisonSessionRejectsDifferentCurrencies() throws {
        var session = ComparisonSession()
        let euro = productCandidate(
            price: "4.99",
            quantity: "0.50",
            bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
        )
        let dollar = ProductCandidate(
            id: UUID(),
            price: Decimal(string: "4.99")!,
            currencyToken: "$",
            normalizedQuantity: Decimal(string: "0.50")!,
            dimension: .mass,
            sourceBounds: CGRect(x: 110, y: 10, width: 80, height: 60),
            confidence: 0.9,
            rawText: ""
        )

        try session.add(euro).get()

        if case .failure(.differentCurrencies) = session.add(dollar) {
            // Expected.
        } else {
            XCTFail("Expected different currency rejection")
        }
    }

    func testComparisonSessionRemoveAndClear() throws {
        var session = ComparisonSession()
        let first = productCandidate(
            price: "4.99",
            quantity: "0.50",
            bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
        )
        let second = productCandidate(
            price: "7.49",
            quantity: "1.00",
            bounds: CGRect(x: 110, y: 10, width: 80, height: 60)
        )

        try session.add(first).get()
        try session.add(second).get()

        session.remove(id: first.id)
        XCTAssertEqual(session.items.map(\.id), [second.id])

        session.clear()
        XCTAssertTrue(session.items.isEmpty)
    }

    func testCandidatePairSelectorRefusesMoreThanTwoCandidates() {
        let candidates = [
            productCandidate(
                price: "1.99",
                quantity: "0.25",
                bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
            ),
            productCandidate(
                price: "2.99",
                quantity: "0.50",
                bounds: CGRect(x: 110, y: 10, width: 80, height: 60)
            ),
            productCandidate(
                price: "4.99",
                quantity: "1.00",
                bounds: CGRect(x: 210, y: 10, width: 80, height: 60)
            )
        ]

        XCTAssertEqual(
            CandidatePairSelector.select(from: candidates),
            .tooMany
        )
    }

    func testCandidatePairSelectorCollapsesDuplicateBeforeCounting() {
        let first = productCandidate(
            price: "1.99",
            quantity: "0.25",
            bounds: CGRect(x: 10, y: 10, width: 80, height: 60)
        )
        let duplicate = productCandidate(
            price: "1.99",
            quantity: "0.25",
            bounds: CGRect(x: 14, y: 14, width: 80, height: 60),
            confidence: 0.8
        )
        let second = productCandidate(
            price: "2.99",
            quantity: "0.50",
            bounds: CGRect(x: 210, y: 10, width: 80, height: 60)
        )

        switch CandidatePairSelector.select(
            from: [first, duplicate, second]
        ) {
        case .pair(let a, let b):
            XCTAssertEqual(a.price, Decimal(string: "1.99"))
            XCTAssertEqual(b.price, Decimal(string: "2.99"))
        default:
            XCTFail("Expected exactly one deduplicated pair")
        }
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

    private func productCandidate(
        price: String,
        quantity: String,
        bounds: CGRect,
        confidence: Float = 0.9
    ) -> ProductCandidate {
        ProductCandidate(
            id: UUID(),
            price: Decimal(string: price)!,
            currencyToken: "€",
            normalizedQuantity: Decimal(string: quantity)!,
            dimension: .mass,
            sourceBounds: bounds,
            confidence: confidence,
            rawText: ""
        )
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
