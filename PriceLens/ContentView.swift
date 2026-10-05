import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scannerModel = ScannerModel()

    @State private var feedbackTrigger = 0
    @State private var lastFeedbackSignature: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraLayer

            if scannerModel.cameraState == .ready {
                cameraScrims
                candidateOverlay
                scannerChrome
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onChange(of: scannerModel.scanState) { _, newState in
            handleFeedback(for: newState)
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
    }

    @ViewBuilder
    private var cameraLayer: some View {
        switch scannerModel.cameraState {
        case .ready:
            GeometryReader { proxy in
                ScannerView(model: scannerModel)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

        case .preparing:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text("Opening camera…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

        case .denied:
            recoveryView(
                symbol: "camera.fill",
                title: "Camera access is off",
                detail: "Allow camera access to compare price labels.",
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
                    .black.opacity(0.48),
                    .black.opacity(0.14),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.16),
                    .black.opacity(0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var scannerChrome: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)

            Spacer(minLength: 0)

            statusCard
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.body.weight(.semibold))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text("Compare prices")
                    .font(.subheadline.weight(.semibold))

                Text("Price Lens")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer(minLength: 8)

            ScanProgressPill(
                count: progressCount,
                isTooMany: isTooMany
            )
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            .black.opacity(0.48),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isTooMany
                ? "Too many price labels in view"
                : "\(progressCount) of 2 price labels found"
        )
    }

    private var candidateOverlay: some View {
        GeometryReader { proxy in
            let candidates = Array(
                scannerModel.visibleCandidates.prefix(2)
            )
            let fullBounds = CGRect(
                origin: .zero,
                size: proxy.size
            )
            let scanRegion = ScanRegionLayout.rect(
                in: fullBounds
            ) ?? .zero

            ZStack {
                ScanRegionGuide(bounds: scanRegion)

                ForEach(candidates.indices, id: \.self) { index in
                    CandidateFrame(
                        label: index == 0 ? "A" : "B",
                        bounds: candidates[index].sourceBounds
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusCard: some View {
        switch scannerModel.scanState {
        case .searching:
            ScanStatusPanel(
                symbol: "viewfinder",
                title: "Aim at 2 price labels",
                detail: "No tap needed — keep both inside the corners"
            )

        case .oneTagFound:
            ScanStatusPanel(
                symbol: "checkmark.circle.fill",
                title: "First label found",
                detail: "Keep it visible and add the second"
            )

        case .tooManyTags:
            ScanStatusPanel(
                symbol: "exclamationmark.triangle.fill",
                title: "Too many labels",
                detail: "Move closer until only two remain",
                emphasis: .warning
            )

        case .comparing:
            ScanStatusPanel(
                symbol: "arrow.left.arrow.right",
                title: "Comparing…",
                detail: "Hold steady for a moment",
                showsProgress: true
            )

        case .incompatible(let message):
            ScanStatusPanel(
                symbol: "exclamationmark.circle.fill",
                title: "Can't compare these",
                detail: message,
                emphasis: .warning
            )

        case .result(let comparison):
            ResultCard(comparison: comparison)
        }
    }

    private var progressCount: Int {
        switch scannerModel.scanState {
        case .searching:
            return 0
        case .oneTagFound:
            return 1
        case .tooManyTags:
            return 2
        case .comparing, .result(_), .incompatible(_):
            return 2
        }
    }

    private var isTooMany: Bool {
        if case .tooManyTags = scannerModel.scanState {
            return true
        }
        return false
    }

    private func handleFeedback(for state: ScanState) {
        switch state {
        case .result(let comparison):
            let signature =
                comparison.left.semanticSignature
                + "|"
                + comparison.right.semanticSignature

            guard signature != lastFeedbackSignature else {
                return
            }

            lastFeedbackSignature = signature
            feedbackTrigger += 1

        case .searching, .tooManyTags:
            lastFeedbackSignature = nil

        default:
            break
        }
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

private struct ScanProgressPill: View {
    let count: Int
    let isTooMany: Bool

    var body: some View {
        HStack(spacing: 7) {
            if isTooMany {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))

                Text("3+")
                    .font(.caption.monospacedDigit().weight(.bold))
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(
                                index < count
                                    ? Color.white
                                    : Color.white.opacity(0.22)
                            )
                            .frame(width: 7, height: 7)
                    }
                }

                Text("\(count)/2")
                    .font(.caption.monospacedDigit().weight(.bold))
            }
        }
        .frame(minWidth: 58)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            .white.opacity(0.10),
            in: Capsule()
        )
    }
}

private enum ScanStatusEmphasis {
    case normal
    case warning
}

private struct ScanStatusPanel: View {
    let symbol: String
    let title: String
    let detail: String
    var showsProgress: Bool = false
    var emphasis: ScanStatusEmphasis = .normal

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 42, height: 42)

                if showsProgress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            emphasis == .warning
                                ? Color.yellow
                                : Color.white
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(
            .black.opacity(0.56),
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

private struct ScanRegionGuide: View {
    let bounds: CGRect

    var body: some View {
        ScanCornersShape()
            .stroke(
                .white.opacity(0.88),
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
                color: .black.opacity(0.35),
                radius: 4
            )
    }
}

private struct ScanCornersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(
            30,
            min(rect.width, rect.height) * 0.12
        )

        var path = Path()

        path.move(to: CGPoint(
            x: rect.minX,
            y: rect.minY + length
        ))
        path.addLine(to: CGPoint(
            x: rect.minX,
            y: rect.minY
        ))
        path.addLine(to: CGPoint(
            x: rect.minX + length,
            y: rect.minY
        ))

        path.move(to: CGPoint(
            x: rect.maxX - length,
            y: rect.minY
        ))
        path.addLine(to: CGPoint(
            x: rect.maxX,
            y: rect.minY
        ))
        path.addLine(to: CGPoint(
            x: rect.maxX,
            y: rect.minY + length
        ))

        path.move(to: CGPoint(
            x: rect.maxX,
            y: rect.maxY - length
        ))
        path.addLine(to: CGPoint(
            x: rect.maxX,
            y: rect.maxY
        ))
        path.addLine(to: CGPoint(
            x: rect.maxX - length,
            y: rect.maxY
        ))

        path.move(to: CGPoint(
            x: rect.minX + length,
            y: rect.maxY
        ))
        path.addLine(to: CGPoint(
            x: rect.minX,
            y: rect.maxY
        ))
        path.addLine(to: CGPoint(
            x: rect.minX,
            y: rect.maxY - length
        ))

        return path
    }
}

private struct CandidateFrame: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    let bounds: CGRect

    var body: some View {
        let expanded = bounds.insetBy(
            dx: -8,
            dy: -8
        )

        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.96),
                lineWidth: 2
            )

            Text(label)
                .font(.caption2.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())
                .offset(x: 8, y: 8)
                .shadow(
                    color: .black.opacity(0.30),
                    radius: 3,
                    y: 1
                )
        }
        .frame(
            width: max(44, expanded.width),
            height: max(44, expanded.height)
        )
        .position(
            x: expanded.midX,
            y: expanded.midY
        )
        .shadow(
            color: .black.opacity(0.22),
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

private struct ResultCard: View {
    let comparison: PriceComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BEST VALUE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.54))

                    Text(comparison.headline)
                        .font(.title3.weight(.bold))
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }

                Spacer(minLength: 8)

                Image(
                    systemName:
                        comparison.winner == .equal
                            ? "equal.circle.fill"
                            : "checkmark.circle.fill"
                )
                .font(.title2)
                .foregroundStyle(
                    comparison.winner == .equal
                        ? Color.white
                        : Color.green
                )
                .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                priceColumn(
                    title: "A",
                    value: comparison.left.unitPrice,
                    isWinner: comparison.winner == .left
                )

                priceColumn(
                    title: "B",
                    value: comparison.right.unitPrice,
                    isWinner: comparison.winner == .right
                )
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(comparison.headline)
        .accessibilityValue(
            "A \(comparison.formattedUnitPrice(comparison.left.unitPrice)) per \(comparison.unitLabel), "
            + "B \(comparison.formattedUnitPrice(comparison.right.unitPrice)) per \(comparison.unitLabel)"
        )
    }

    private func priceColumn(
        title: String,
        value: Decimal,
        isWinner: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(0.7)

                if isWinner {
                    Text("BEST")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.green, in: Capsule())
                }
            }

            Text(comparison.formattedUnitPrice(value))
                .font(.title3.monospacedDigit().weight(.semibold))

            Text("per \(comparison.unitLabel)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(12)
        .background(
            .white.opacity(isWinner ? 0.15 : 0.07),
            in: RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                isWinner
                    ? .white.opacity(0.24)
                    : .clear,
                lineWidth: 1
            )
        )
    }
}

#Preview {
    ContentView()
}
