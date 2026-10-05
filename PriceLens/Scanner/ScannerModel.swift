import AVFoundation
import Combine
import Foundation
import VisionKit

@MainActor
final class ScannerModel: ObservableObject {
    @Published private(set) var cameraState: CameraState = .preparing
    @Published private(set) var scanState: ScanState = .searching
    @Published private(set) var visibleCandidates: [ProductCandidate] = []

    private var stabilizer = RecognitionStabilizer()
    private var missingUpdateCount = 0

    func prepareCamera() async {
        cameraState = .preparing

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

        if candidates.count > 2 {
            visibleCandidates = []
            stabilizer.reset()
            missingUpdateCount = 0
            scanState = .tooManyTags
            return
        }

        guard candidates.count >= 2 else {
            missingUpdateCount += 1

            // Preserve a valid result through a couple of transient OCR drops.
            // Live text tracking can briefly lose a line while the camera moves.
            if case .result = scanState, missingUpdateCount < 3 {
                return
            }

            stabilizer.reset()

            if candidates.count == 1 {
                visibleCandidates = candidates
                scanState = .oneTagFound
            } else if missingUpdateCount >= 3 {
                visibleCandidates = []
                scanState = .searching
                stabilizer.reset()
            }
            return
        }

        missingUpdateCount = 0

        // Exactly two valid candidates are required. If there are more, the
        // scanner asks the user to tighten the frame instead of guessing.
        let ordered = CandidateOrdering.ordered(candidates)

        guard ordered.count == 2 else {
            visibleCandidates = []
            scanState = .searching
            return
        }

        visibleCandidates = ordered

        let left = ordered[0]
        let right = ordered[1]

        switch ComparisonEngine.compare(left: left, right: right) {
        case .failure(let failure):
            stabilizer.reset()
            scanState = .incompatible(failure.message)

        case .success(let comparison):
            let signature = left.semanticSignature + "|" + right.semanticSignature
            let isStable = stabilizer.observe(
                signature: signature,
                at: ProcessInfo.processInfo.systemUptime
            )

            scanState = isStable ? .result(comparison) : .comparing
        }
    }

    func scannerBecameUnavailable(_ message: String) {
        visibleCandidates = []
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
