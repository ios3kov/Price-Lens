import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scannerModel = ScannerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraLayer

            if scannerModel.cameraState == .ready {
                candidateOverlay
            }

            VStack(spacing: 16) {
                header
                Spacer()
                statusCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
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
    }

    @ViewBuilder
    private var cameraLayer: some View {
        switch scannerModel.cameraState {
        case .ready:
            ScannerView(model: scannerModel)
                .ignoresSafeArea()

        case .preparing:
            ProgressView()
                .tint(.white)

        case .denied:
            cameraDeniedView

        case .unsupported:
            unavailableView(
                title: "This iPhone is not supported",
                detail: "Price Lens requires an A12 Bionic chip or newer."
            )

        case .failed(let message):
            cameraFailedView(message)
        }
    }

    private var candidateOverlay: some View {
        GeometryReader { proxy in
            let candidates = Array(scannerModel.visibleCandidates.prefix(2))
            let fullBounds = CGRect(origin: .zero, size: proxy.size)
            let scanRegion = ScanRegionLayout.rect(in: fullBounds) ?? .zero

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

    private var header: some View {
        HStack {
            Text("PRICE LENS")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(.black.opacity(0.48), in: Capsule())
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var statusCard: some View {
        switch scannerModel.cameraState {
        case .ready:
            switch scannerModel.scanState {
            case .searching:
                HintCard(
                    title: "Point at two price tags",
                    detail: "Keep both price tags inside the frame"
                )

            case .oneTagFound:
                HintCard(
                    title: "One tag found",
                    detail: "Move slightly so both tags are inside the frame"
                )

            case .tooManyTags:
                HintCard(
                    title: "Too many price tags",
                    detail: "Move closer so only two tags are inside the frame"
                )

            case .comparing:
                HintCard(
                    title: "Comparing…",
                    detail: "Hold still for a moment",
                    showsProgress: true
                )

            case .incompatible(let message):
                HintCard(
                    title: "Can't compare these yet",
                    detail: message
                )

            case .result(let comparison):
                ResultCard(comparison: comparison)
            }

        default:
            EmptyView()
        }
    }

    private func cameraFailedView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .semibold))

            Text("Camera unavailable")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Try Again") {
                Task {
                    await scannerModel.prepareCamera()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .foregroundStyle(.white)
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .semibold))

            Text("Camera access is off")
                .font(.headline)

            Text("Enable camera access for Price Lens in Settings.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Open Settings") {
                guard let url = URL(
                    string: UIApplication.openSettingsURLString
                ) else {
                    return
                }
                openURL(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .foregroundStyle(.white)
    }

    private func unavailableView(
        title: String,
        detail: String
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .semibold))
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .foregroundStyle(.white)
    }
}

private struct HintCard: View {
    let title: String
    let detail: String
    var showsProgress: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: "viewfinder")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct ScanRegionGuide: View {
    let bounds: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .stroke(
                .white.opacity(0.38),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    dash: [12, 9]
                )
            )
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
    }
}

private struct CandidateFrame: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    let bounds: CGRect

    var body: some View {
        let expanded = bounds.insetBy(dx: -8, dy: -8)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.96), lineWidth: 2)

            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white, in: Capsule())
                .offset(x: 8, y: 8)
        }
        .frame(
            width: max(44, expanded.width),
            height: max(44, expanded.height)
        )
        .position(x: expanded.midX, y: expanded.midY)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: bounds
        )
    }
}

private struct ResultCard: View {
    let comparison: PriceComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(comparison.headline)
                    .font(.title3.weight(.bold))
            }

            HStack(spacing: 10) {
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
        .padding(18)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(comparison.headline)
        .accessibilityValue(
            "A \(comparison.formattedUnitPrice(comparison.left.unitPrice)) per \(comparison.unitLabel), " +
            "B \(comparison.formattedUnitPrice(comparison.right.unitPrice)) per \(comparison.unitLabel)"
        )
    }

    private func priceColumn(
        title: String,
        value: Decimal,
        isWinner: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(1)

                if isWinner {
                    Image(systemName: "arrow.down.circle.fill")
                        .accessibilityHidden(true)
                }
            }

            Text(comparison.formattedUnitPrice(value))
                .font(.headline.monospacedDigit())

            Text("per \(comparison.unitLabel)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            .white.opacity(isWinner ? 0.18 : 0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

#Preview {
    ContentView()
}
