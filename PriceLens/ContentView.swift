import SwiftUI

struct ContentView: View {
    @StateObject private var scannerModel = ScannerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraLayer

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
            unavailableView(
                title: "Camera access is off",
                detail: "Enable camera access for Price Lens in Settings."
            )

        case .unsupported:
            unavailableView(
                title: "This iPhone is not supported",
                detail: "Price Lens requires an A12 Bionic chip or newer."
            )

        case .failed(let message):
            unavailableView(
                title: "Camera unavailable",
                detail: message
            )
        }
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
                    detail: "Keep price and package size visible"
                )

            case .oneTagFound:
                HintCard(
                    title: "One tag found",
                    detail: "Move slightly so both tags are visible"
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
                    title: "LEFT",
                    value: comparison.left.unitPrice,
                    isWinner: comparison.winner == .left
                )

                priceColumn(
                    title: "RIGHT",
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
