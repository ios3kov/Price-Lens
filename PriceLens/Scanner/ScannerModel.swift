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
    private var dropoutGate = DropoutGraceGate()
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
            cameraState = .failed("Live text scanner is currently unavailable")
            return
        }

        cameraState = .ready
    }

    func receive(_ items: [ScannedText]) {
        let candidates = TagClusterer.clusters(from: items)
            .compactMap(PriceTagParser.parse(cluster:))

        switch CandidatePairSelector.select(from: candidates) {
        case .tooMany:
            dropoutGate.cancel()
            visibleCandidates = []
            stabilizer.reset()
            missingUpdateCount = 0
            scanState = .tooManyTags
            return

        case .none:
            missingUpdateCount += 1

            if case .result = scanState {
                scheduleResultDropout(fallbackCandidates: [])
                return
            }

            dropoutGate.cancel()
            stabilizer.reset()

            if missingUpdateCount >= 3 {
                visibleCandidates = []
                scanState = .searching
            }
            return

        case .one(let candidate):
            missingUpdateCount += 1

            if case .result = scanState {
                scheduleResultDropout(
                    fallbackCandidates: [candidate]
                )
                return
            }

            dropoutGate.cancel()
            stabilizer.reset()
            visibleCandidates = [candidate]
            scanState = .oneTagFound
            return

        case .pair(let left, let right):
            dropoutGate.cancel()
            missingUpdateCount = 0
            visibleCandidates = [left, right]

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
    }

    func scannerBecameUnavailable(_ message: String) {
        resetRecognition()
        cameraState = .failed(message)
    }

    private func resetRecognition() {
        dropoutGate.cancel()
        stabilizer.reset()
        missingUpdateCount = 0
        visibleCandidates = []
        scanState = .searching
    }

    private func scheduleResultDropout(
        fallbackCandidates: [ProductCandidate]
    ) {
        guard let generation = dropoutGate.begin() else {
            return
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard let self,
                  self.dropoutGate.complete(generation: generation),
                  case .result = self.scanState else {
                return
            }

            self.stabilizer.reset()
            self.visibleCandidates = fallbackCandidates

            if fallbackCandidates.count == 1 {
                self.scanState = .oneTagFound
            } else {
                self.visibleCandidates = []
                self.scanState = .searching
            }
        }
    }

}
