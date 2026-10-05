import SwiftUI
import Vision
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    let model: ScannerModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )

        scanner.delegate = context.coordinator

        Task { @MainActor in
            scanner.view.layoutIfNeeded()
            if let region = ScanRegionLayout.rect(in: scanner.view.bounds) {
                scanner.regionOfInterest = region
            }

            do {
                try scanner.startScanning()
            } catch {
                model.scannerBecameUnavailable(
                    "Scanner failed: \(error.localizedDescription)"
                )
            }
        }

        return scanner
    }

    func updateUIViewController(
        _ uiViewController: DataScannerViewController,
        context: Context
    ) {
        if let region = ScanRegionLayout.rect(
            in: uiViewController.view.bounds
        ), uiViewController.regionOfInterest != region {
            uiViewController.regionOfInterest = region
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: DataScannerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let model: ScannerModel

        init(model: ScannerModel) {
            self.model = model
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            process(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            process(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            process(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            model.scannerBecameUnavailable(
                "Scanner unavailable: \(String(describing: error))"
            )
        }

        private func process(_ items: [RecognizedItem]) {
            let scanned = items.compactMap { item -> ScannedText? in
                guard case .text(let text) = item else {
                    return nil
                }

                let points = [
                    text.bounds.topLeft,
                    text.bounds.topRight,
                    text.bounds.bottomRight,
                    text.bounds.bottomLeft
                ]

                guard let minX = points.map(\.x).min(),
                      let maxX = points.map(\.x).max(),
                      let minY = points.map(\.y).min(),
                      let maxY = points.map(\.y).max() else {
                    return nil
                }

                let confidence = text.observation
                    .topCandidates(1)
                    .first?
                    .confidence ?? 0.5

                return ScannedText(
                    id: text.id,
                    transcript: text.transcript,
                    bounds: CGRect(
                        x: minX,
                        y: minY,
                        width: maxX - minX,
                        height: maxY - minY
                    ),
                    confidence: confidence
                )
            }

            model.receive(scanned)
        }
    }
}
