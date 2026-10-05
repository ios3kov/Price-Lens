import AVFoundation
import Combine
import Foundation
import VisionKit

@MainActor
final class ScannerModel: ObservableObject {
    @Published private(set) var cameraState: CameraState = .preparing
    @Published private(set) var scanState: ScanState = .searching
    @Published private(set) var currentCandidate: ProductCandidate?
    @Published private(set) var comparisonItems: [ProductCandidate] = []

    private var stabilizer = RecognitionStabilizer()
    private var session = ComparisonSession()
    private var missingUpdateCount = 0

    func prepareCamera() async {
        resetRecognition()
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
            cameraState = .failed(
                "Live text scanner is currently unavailable"
            )
            return
        }

        cameraState = .ready
    }

    func receive(_ items: [ScannedText]) {
        let candidates = CandidateDeduplicator.deduplicated(
            TagClusterer.clusters(from: items)
                .compactMap(PriceTagParser.parse(cluster:))
        )

        guard candidates.count <= 1 else {
            currentCandidate = nil
            stabilizer.reset()
            missingUpdateCount = 0
            scanState = .tooManyTags
            return
        }

        guard let candidate = candidates.first else {
            missingUpdateCount += 1

            if !items.isEmpty {
                currentCandidate = nil
                stabilizer.reset()
                scanState = .textFound
                return
            }

            if missingUpdateCount >= 2 {
                currentCandidate = nil
                stabilizer.reset()
                scanState = .searching
            }
            return
        }

        missingUpdateCount = 0
        currentCandidate = candidate

        switch session.compatibility(with: candidate) {
        case .failure(.duplicate):
            stabilizer.reset()
            scanState = .alreadyAdded

        case .failure(let error):
            stabilizer.reset()
            scanState = .incompatible(error.message)

        case .success:
            let stable = stabilizer.observe(
                signature: candidate.semanticSignature,
                at: ProcessInfo.processInfo.systemUptime
            )
            scanState = stable ? .ready : .reading
        }
    }

    func addCurrentCandidate() {
        guard let currentCandidate else {
            return
        }

        switch session.add(currentCandidate) {
        case .success:
            comparisonItems = session.items
            stabilizer.reset()
            scanState = .alreadyAdded

        case .failure(.duplicate):
            stabilizer.reset()
            scanState = .alreadyAdded

        case .failure(let error):
            stabilizer.reset()
            scanState = .incompatible(error.message)
        }
    }

    func removeComparisonItem(id: UUID) {
        session.remove(id: id)
        comparisonItems = session.items
        reevaluateCurrentCandidate()
    }

    func clearComparison() {
        session.clear()
        comparisonItems = []
        reevaluateCurrentCandidate()
    }

    var rankedComparisonItems: [ProductCandidate] {
        session.rankedItems
    }

    var bestItemID: UUID? {
        session.bestItem?.id
    }

    func savingsPercent(
        versus candidate: ProductCandidate
    ) -> Decimal? {
        session.savingsPercent(versus: candidate)
    }

    func appBecameInactive() {
        resetRecognition()

        if cameraState == .ready {
            // Removing ScannerView stops the active DataScanner session.
            // A fresh session is created when the app becomes active again.
            cameraState = .preparing
        }
    }

    func scannerBecameUnavailable(_ message: String) {
        resetRecognition()
        cameraState = .failed(message)
    }

    private func resetRecognition() {
        stabilizer.reset()
        missingUpdateCount = 0
        currentCandidate = nil
        scanState = .searching
    }

    private func reevaluateCurrentCandidate() {
        stabilizer.reset()

        guard let currentCandidate else {
            scanState = .searching
            return
        }

        switch session.compatibility(with: currentCandidate) {
        case .success:
            scanState = .reading

        case .failure(.duplicate):
            scanState = .alreadyAdded

        case .failure(let error):
            scanState = .incompatible(error.message)
        }
    }
}
