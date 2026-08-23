import SwiftUI
import SceneKit

/// Displays the scanned 3D face model with interactive rotation and zoom.
/// Provides export options (OBJ and USDZ) via a share sheet.
struct Viewer3DView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var showExportOptions = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.scanSession.state == .completed,
                   !viewModel.scanSession.finalVertices.isEmpty {
                    modelViewer
                } else {
                    placeholderView
                }
            }
            .navigationTitle("3D Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.scanSession.state == .completed {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                exportAsOBJ()
                            } label: {
                                Label("Export as OBJ", systemImage: "doc.text")
                            }

                            Button {
                                exportAsUSDZ()
                            } label: {
                                Label("Export as USDZ", systemImage: "arkit")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.resetScan()
                        } label: {
                            Label("New Scan", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheetView(activityItems: [url])
                }
            }
        }
    }

    // MARK: - 3D Model Viewer

    private var modelViewer: some View {
        VStack(spacing: 0) {
            SceneKitContainer(
                vertices: viewModel.scanSession.finalVertices,
                normals: viewModel.scanSession.finalNormals,
                texCoords: viewModel.scanSession.finalTexCoords,
                indices: viewModel.scanSession.finalIndices
            )
            .ignoresSafeArea(edges: .bottom)

            // Info bar
            HStack {
                Label(
                    "\(viewModel.scanSession.finalVertices.count) vertices",
                    systemImage: "circle.grid.3x3"
                )
                Spacer()
                Label(
                    "\(viewModel.scanSession.finalIndices.count / 3) triangles",
                    systemImage: "triangle"
                )
                Spacer()
                Label("Pinch to zoom", systemImage: "hand.pinch")
            }
            .font(.caption)
            .foregroundStyle(.gray)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 64))
                .foregroundStyle(.gray.opacity(0.5))

            Text("No Scan Data")
                .font(.title3.bold())
                .foregroundStyle(.gray)

            Text("Complete a face scan to view\nyour 3D model here.")
                .font(.subheadline)
                .foregroundStyle(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Export

    private func exportAsOBJ() {
        let session = viewModel.scanSession
        if let url = OBJExporter.export(
            vertices: session.finalVertices,
            normals: session.finalNormals,
            texCoords: session.finalTexCoords,
            indices: session.finalIndices
        ) {
            exportedFileURL = url
            showShareSheet = true
            HapticManager.shared.notification(.success)
        } else {
            HapticManager.shared.notification(.error)
        }
    }

    private func exportAsUSDZ() {
        let session = viewModel.scanSession
        if let url = USDZExporter.export(
            vertices: session.finalVertices,
            normals: session.finalNormals,
            texCoords: session.finalTexCoords,
            indices: session.finalIndices
        ) {
            exportedFileURL = url
            showShareSheet = true
            HapticManager.shared.notification(.success)
        } else {
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - SceneKit Container

/// UIViewRepresentable wrapping SCNView for 3D model display.
/// Configures interactive camera control (rotate 360 degrees, pinch zoom) and studio lighting.
struct SceneKitContainer: UIViewRepresentable {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let texCoords: [SIMD2<Float>]
    let indices: [Int16]

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = buildScene()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        guard !vertices.isEmpty else { return scene }

        // Geometry sources
        let positions = vertices.map { SCNVector3($0.x, $0.y, $0.z) }
        let positionSource = SCNGeometrySource(vertices: positions)

        let normalVectors = normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let normalSource = SCNGeometrySource(normals: normalVectors)

        let texCoordSource = SCNGeometrySource(
            textureCoordinates: texCoords.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        )

        // Geometry element (triangles)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int16>.stride)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<Int16>.stride
        )

        let geometry = SCNGeometry(
            sources: [positionSource, normalSource, texCoordSource],
            elements: [element]
        )

        // PBR material with skin tone
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.87, green: 0.77, blue: 0.68, alpha: 1.0)
        material.specular.contents = UIColor(white: 0.4, alpha: 1.0)
        material.roughness.contents = NSNumber(value: 0.6)
        material.metalness.contents = NSNumber(value: 0.0)
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        geometry.materials = [material]

        let meshNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(meshNode)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 0, 0.4)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Studio lighting setup
        addStudioLighting(to: scene)

        return scene
    }

    private func addStudioLighting(to scene: SCNScene) {
        // Ambient fill
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        ambient.light?.color = UIColor(white: 0.6, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        // Key light (warm, from upper-right)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 900
        keyLight.light?.color = UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1.0)
        keyLight.light?.castsShadow = true
        keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(keyLight)

        // Fill light (cool, from lower-left)
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 450
        fillLight.light?.color = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1.0)
        fillLight.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 4, 0)
        scene.rootNode.addChildNode(fillLight)

        // Rim/back light
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 300
        rimLight.light?.color = UIColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 1.0)
        rimLight.eulerAngles = SCNVector3(Float.pi / 6, Float.pi, 0)
        scene.rootNode.addChildNode(rimLight)
    }
}

// MARK: - Share Sheet

/// UIActivityViewController wrapper for SwiftUI.
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
