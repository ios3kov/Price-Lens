import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scannerModel = ScannerModel()

    @State private var feedbackTrigger = 0
    @State private var previousItemCount = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                cameraLayer
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )

                if scannerModel.cameraState == .ready {
                    cameraScrims
                    candidateOverlay

                    VStack(spacing: 12) {
                        topBar
                        Spacer(minLength: 0)
                        bottomArea
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
        }
        .preferredColorScheme(.dark)
        .task {
            await scannerModel.prepareCamera()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                guard scannerModel.cameraState != .ready else {
                    return
                }

                Task {
                    await scannerModel.prepareCamera()
                }
            } else {
                scannerModel.appBecameInactive()
            }
        }
        .onChange(of: scannerModel.comparisonItems.count) { _, newCount in
            if newCount > previousItemCount {
                feedbackTrigger += 1
            }
            previousItemCount = newCount
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
    }

    @ViewBuilder
    private var cameraLayer: some View {
        switch scannerModel.cameraState {
        case .ready:
            ScannerView(model: scannerModel)
                .ignoresSafeArea()

        case .preparing:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text("Opening camera…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.70))
            }

        case .denied:
            recoveryView(
                symbol: "camera.fill",
                title: "Camera access is off",
                detail: "Allow camera access to scan price labels.",
                buttonTitle: "Open Settings"
            ) {
                guard let url = URL(
                    string: UIApplication.openSettingsURLString
                ) else {
                    return
                }
                openURL(url)
            }

        case .unsupported:
            recoveryView(
                symbol: "iphone.slash",
                title: "This iPhone isn't supported",
                detail: "Price Lens requires an A12 Bionic chip or newer.",
                buttonTitle: nil,
                action: nil
            )

        case .failed(let message):
            recoveryView(
                symbol: "camera.fill",
                title: "Camera unavailable",
                detail: message,
                buttonTitle: "Try Again"
            ) {
                Task {
                    await scannerModel.prepareCamera()
                }
            }
        }
    }

    private var cameraScrims: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    .black.opacity(0.72),
                    .black.opacity(0.12),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 130)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.18),
                    .black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Price Lens")
                    .font(.headline.weight(.semibold))

                Text(
                    scannerModel.comparisonItems.isEmpty
                        ? "Scan one label at a time"
                        : "\(scannerModel.comparisonItems.count) item\(scannerModel.comparisonItems.count == 1 ? "" : "s") in comparison"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
            }

            Spacer(minLength: 8)

            if !scannerModel.comparisonItems.isEmpty {
                Button("Clear") {
                    scannerModel.clearComparison()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.82))
                .accessibilityLabel("Clear comparison")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            .black.opacity(0.50),
            in: RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var bottomArea: some View {
        VStack(spacing: 10) {
            if !scannerModel.comparisonItems.isEmpty {
                comparisonTray
            }

            actionPanel
        }
    }

    private var comparisonTray: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                if let bestID = scannerModel.bestItemID,
                   scannerModel.comparisonItems.count >= 2,
                   let bestIndex = scannerModel.comparisonItems.firstIndex(
                    where: { $0.id == bestID }
                   ) {
                    Label(
                        "Best value: Item \(bestIndex + 1)",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                } else {
                    Text(
                        scannerModel.comparisonItems.count == 1
                            ? "1 item added"
                            : "\(scannerModel.comparisonItems.count) items added"
                    )
                    .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 8)

                Text("Add more anytime")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(
                        Array(scannerModel.comparisonItems.enumerated()),
                        id: \.element.id
                    ) { index, candidate in
                        ComparisonItemCard(
                            index: index + 1,
                            candidate: candidate,
                            isBest:
                                scannerModel.comparisonItems.count >= 2
                                && candidate.id == scannerModel.bestItemID
                        ) {
                            scannerModel.removeComparisonItem(
                                id: candidate.id
                            )
                        }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(
            .black.opacity(0.62),
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionPanel: some View {
        switch scannerModel.scanState {
        case .searching:
            InstructionCard(
                symbol: "viewfinder",
                title: "Scan a price label",
                detail: scannerModel.comparisonItems.isEmpty
                    ? "Place one label inside the frame"
                    : "Point at the next label to add it"
            )

        case .textFound:
            InstructionCard(
                symbol: "text.viewfinder",
                title: "Text found",
                detail: "Looking for a price and pack size…"
            )

        case .reading:
            if let candidate = scannerModel.currentCandidate {
                CandidateCard(
                    candidate: candidate,
                    mode: .reading,
                    addAction: nil
                )
            } else {
                InstructionCard(
                    symbol: "text.viewfinder",
                    title: "Reading label…",
                    detail: "Hold steady for a moment"
                )
            }

        case .ready:
            if let candidate = scannerModel.currentCandidate {
                CandidateCard(
                    candidate: candidate,
                    mode: .ready
                ) {
                    scannerModel.addCurrentCandidate()
                }
            }

        case .alreadyAdded:
            InstructionCard(
                symbol: "checkmark.circle.fill",
                title: "Already added",
                detail: "Move to another price label"
            )

        case .tooManyTags:
            InstructionCard(
                symbol: "rectangle.and.text.magnifyingglass",
                title: "One label at a time",
                detail: "Center a single price label inside the frame",
                isWarning: true
            )

        case .incompatible(let message):
            IncompatibleCard(
                message: message,
                clearAction: scannerModel.clearComparison
            )
        }
    }

    private var candidateOverlay: some View {
        GeometryReader { proxy in
            let fullBounds = CGRect(
                origin: .zero,
                size: proxy.size
            )
            let scanRegion = ScanRegionLayout.rect(
                in: fullBounds
            ) ?? .zero

            ZStack {
                ScanRegionGuide(bounds: scanRegion)

                if let candidate = scannerModel.currentCandidate {
                    CandidateFrame(
                        bounds: candidate.sourceBounds,
                        isReady: scannerModel.scanState == .ready
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func recoveryView(
        symbol: String,
        title: String,
        detail: String,
        buttonTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(
                    .white.opacity(0.08),
                    in: Circle()
                )

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 360)
        .background(
            .white.opacity(0.07),
            in: RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

private struct InstructionCard: View {
    let symbol: String
    let title: String
    let detail: String
    var isWarning: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    isWarning
                        ? Color.yellow
                        : Color.white
                )
                .frame(width: 42, height: 42)
                .background(
                    .white.opacity(0.10),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(
            .black.opacity(0.64),
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private enum CandidateCardMode: Equatable {
    case reading
    case ready
}

private struct CandidateCard: View {
    let candidate: ProductCandidate
    let mode: CandidateCardMode
    let addAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    mode == .ready
                        ? "Label ready"
                        : "Reading label…"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(candidate.formattedPrice)
                        .font(.title3.monospacedDigit().weight(.bold))

                    Text("•")
                        .foregroundStyle(.white.opacity(0.35))

                    Text(candidate.formattedQuantity)
                        .font(.subheadline.weight(.semibold))
                }

                Text(
                    "\(candidate.formattedUnitPrice) per \(candidate.dimension.unitLabel)"
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 8)

            if mode == .ready, let addAction {
                Button(action: addAction) {
                    Label("Add", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Add this price label to comparison")
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(
            .black.opacity(0.66),
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                mode == .ready
                    ? .white.opacity(0.24)
                    : .white.opacity(0.12),
                lineWidth: 1
            )
        )
    }
}

private struct IncompatibleCard: View {
    let message: String
    let clearAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.yellow)
                .frame(width: 42, height: 42)
                .background(
                    .white.opacity(0.10),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Can't add this item")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 8)

            Button("Start new") {
                clearAction()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(
            .black.opacity(0.66),
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(.yellow.opacity(0.30), lineWidth: 1)
        )
    }
}

private struct ComparisonItemCard: View {
    let index: Int
    let candidate: ProductCandidate
    let isBest: Bool
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("Item \(index)")
                    .font(.caption.weight(.bold))

                if isBest {
                    Text("BEST")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green, in: Capsule())
                }

                Spacer(minLength: 4)

                Button(action: removeAction) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove item \(index)")
            }

            Text(candidate.formattedUnitPrice)
                .font(.subheadline.monospacedDigit().weight(.semibold))

            Text("per \(candidate.dimension.unitLabel)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(width: 126, alignment: .leading)
        .padding(10)
        .background(
            .white.opacity(isBest ? 0.16 : 0.07),
            in: RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .stroke(
                isBest
                    ? .white.opacity(0.24)
                    : .white.opacity(0.08),
                lineWidth: 1
            )
        )
    }
}

private struct ScanRegionGuide: View {
    let bounds: CGRect

    var body: some View {
        ScanCornersShape()
            .stroke(
                .white.opacity(0.90),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(
                width: bounds.width,
                height: bounds.height
            )
            .position(
                x: bounds.midX,
                y: bounds.midY
            )
            .shadow(
                color: .black.opacity(0.34),
                radius: 4
            )
    }
}

private struct ScanCornersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(
            28,
            min(rect.width, rect.height) * 0.16
        )

        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}

private struct CandidateFrame: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let bounds: CGRect
    let isReady: Bool

    var body: some View {
        let expanded = bounds.insetBy(dx: -8, dy: -8)

        RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )
        .stroke(
            isReady
                ? Color.green
                : Color.white.opacity(0.94),
            lineWidth: isReady ? 3 : 2
        )
        .frame(
            width: max(44, expanded.width),
            height: max(44, expanded.height)
        )
        .position(
            x: expanded.midX,
            y: expanded.midY
        )
        .shadow(
            color: .black.opacity(0.28),
            radius: 4
        )
        .animation(
            reduceMotion
                ? nil
                : .easeOut(duration: 0.12),
            value: bounds
        )
    }
}

private extension ProductCandidate {
    var formattedPrice: String {
        Self.formatMoney(
            price,
            currencyToken: currencyToken
        )
    }

    var formattedUnitPrice: String {
        Self.formatMoney(
            unitPrice,
            currencyToken: currencyToken
        )
    }

    var formattedQuantity: String {
        let number = NSDecimalNumber(
            decimal: normalizedQuantity
        ).doubleValue

        switch dimension {
        case .mass:
            if number < 1 {
                return "\(Int((number * 1000).rounded())) g"
            }
            return Self.cleanNumber(number) + " kg"

        case .volume:
            if number < 1 {
                return "\(Int((number * 1000).rounded())) ml"
            }
            return Self.cleanNumber(number) + " L"

        case .count:
            return Self.cleanNumber(number) + " pcs"
        }
    }

    private static func formatMoney(
        _ value: Decimal,
        currencyToken: String?
    ) -> String {
        let amount = String(
            format: "%.2f",
            NSDecimalNumber(decimal: value).doubleValue
        )

        guard let currencyToken,
              !currencyToken.isEmpty else {
            return amount
        }

        if ["€", "$", "£", "₽"].contains(currencyToken) {
            return currencyToken + amount
        }

        return amount + " " + currencyToken
    }

    private static func cleanNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        let raw = String(format: "%.2f", value)
        return raw.replacingOccurrences(
            of: #"\.?0+$"#,
            with: "",
            options: .regularExpression
        )
    }
}

#Preview {
    ContentView()
}
