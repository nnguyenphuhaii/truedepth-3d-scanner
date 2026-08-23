import SwiftUI
import ARKit
import SceneKit

/// UIViewRepresentable wrapping ARSCNView for SwiftUI integration.
/// Displays the live TrueDepth camera feed with a cyan wireframe face mesh overlay.
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ScannerViewModel

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = true
        arView.showsStatistics = false
        arView.rendersContinuously = true
        arView.backgroundColor = .black

        // Pass the ARSCNView reference to the ViewModel
        viewModel.setARView(arView)

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No dynamic updates needed; session is managed by ViewModel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        let viewModel: ScannerViewModel
        private let logger = LoggerService.shared

        init(viewModel: ScannerViewModel) {
            self.viewModel = viewModel
            super.init()
        }

        // MARK: ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor else { return nil }

            guard let device = MTLCreateSystemDefaultDevice(),
                  let faceGeometry = ARSCNFaceGeometry(device: device) else {
                logger.log("Failed to create ARSCNFaceGeometry", level: .error)
                return nil
            }

            // Wireframe overlay style
            faceGeometry.firstMaterial?.fillMode = .lines
            faceGeometry.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.8)
            faceGeometry.firstMaterial?.isDoubleSided = true

            let node = SCNNode(geometry: faceGeometry)
            logger.log("Face anchor detected, wireframe overlay created", level: .info)
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }

            // Update wireframe mesh
            faceGeometry.update(from: faceAnchor.geometry)

            // Forward face anchor data to ViewModel
            viewModel.handleFaceAnchorUpdate(faceAnchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            if anchor is ARFaceAnchor {
                DispatchQueue.main.async { [weak self] in
                    self?.viewModel.isFaceDetected = false
                }
                logger.log("Face anchor removed", level: .warning)
            }
        }

        // MARK: ARSessionDelegate - Error handling

        func session(_ session: ARSession, didFailWithError error: Error) {
            logger.log("ARSession error: \(error.localizedDescription)", level: .error)
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.scanSession.state = .failed(error.localizedDescription)
            }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            logger.log("ARSession interrupted (e.g. app backgrounded)", level: .warning)
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            logger.log("ARSession interruption ended", level: .info)
        }
    }
}
