import AVFoundation
import Foundation
import VisionKit

@MainActor
final class ScannerModel: ObservableObject {
    @Published private(set) var cameraState: CameraState = .preparing
    @Published private(set) var scanState: ScanState = .searching

    private var pendingSignature: String?
    private var stableUpdateCount = 0
    private var missingUpdateCount = 0

    func prepareCamera() async {
        guard DataScannerViewController.isSupported else {
            cameraState = .unsupported
            return
        }

        let authorization = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorization {
        case .authorized:
            break

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                cameraState = .denied
                return
            }

        case .denied, .restricted:
            cameraState = .denied
            return

        @unknown default:
            cameraState = .failed("Unknown camera authorization state")
            return
        }

        guard DataScannerViewController.isAvailable else {
            cameraState = .failed("Live text scanner is currently unavailable")
            return
        }

        cameraState = .ready
    }

    func receive(_ items: [ScannedText]) {
        var candidates = TagClusterer.clusters(from: items)
            .compactMap(PriceTagParser.parse(cluster:))

        candidates = deduplicated(candidates)

        guard candidates.count >= 2 else {
            missingUpdateCount += 1

            if candidates.count == 1 {
                scanState = .oneTagFound
            } else if missingUpdateCount >= 3 {
                scanState = .searching
                pendingSignature = nil
                stableUpdateCount = 0
            }
            return
        }

        missingUpdateCount = 0

        // Prefer the two strongest candidates, then restore left-to-right order.
        let strongest = Array(
            candidates
                .sorted { $0.confidence > $1.confidence }
                .prefix(2)
        )
        let ordered = strongest.sorted { $0.centerX < $1.centerX }

        guard ordered.count == 2 else {
            scanState = .searching
            return
        }

        let left = ordered[0]
        let right = ordered[1]

        switch ComparisonEngine.compare(left: left, right: right) {
        case .failure(let failure):
            pendingSignature = nil
            stableUpdateCount = 0
            scanState = .incompatible(failure.message)

        case .success(let comparison):
            let signature = left.semanticSignature + "|" + right.semanticSignature

            if signature == pendingSignature {
                stableUpdateCount += 1
            } else {
                pendingSignature = signature
                stableUpdateCount = 1
            }

            if stableUpdateCount >= 3 {
                scanState = .result(comparison)
            } else {
                scanState = .comparing
            }
        }
    }

    func scannerBecameUnavailable(_ message: String) {
        cameraState = .failed(message)
    }

    private func deduplicated(
        _ candidates: [ProductCandidate]
    ) -> [ProductCandidate] {
        var output: [ProductCandidate] = []

        for candidate in candidates.sorted(by: { $0.confidence > $1.confidence }) {
            let isDuplicate = output.contains { existing in
                existing.semanticSignature == candidate.semanticSignature &&
                abs(existing.centerX - candidate.centerX) < 48
            }

            if !isDuplicate {
                output.append(candidate)
            }
        }

        return output
    }
}
