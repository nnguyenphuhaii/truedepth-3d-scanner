import SwiftUI
import SceneKit

/// Display mode for the 3D Face Model.
enum RenderMode: String, CaseIterable, Identifiable {
    case textured = "Mặt Thật 3D"
    case hybrid = "Lưới + Ảnh"
    case clay = "Tượng Điêu Khắc"
    case wireframe = "Lưới 3D Cyan"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .textured:  return "person.crop.circle.fill"
        case .hybrid:    return "square.stack.3d.up.fill"
        case .clay:      return "circle.fill"
        case .wireframe: return "triangle"
        }
    }
}

/// Displays the scanned 3D face model with interactive rotation and zoom.
/// Features high-resolution real face photo texture mapping and multiple rendering styles.
struct Viewer3DView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @State private var renderMode: RenderMode = .textured
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false

    var hasModelData: Bool {
        !viewModel.scanSession.finalVertices.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if hasModelData {
                    modelViewer
                } else {
                    placeholderView
                }
            }
            .navigationTitle("3D Face Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if hasModelData {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.resetScan()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Quét Lại")
                            }
                            .font(.caption.bold())
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                exportAsOBJ()
                            } label: {
                                Label("Xuất file Wavefront OBJ (.obj + .mtl + Texture)", systemImage: "doc.text")
                            }

                            Button {
                                exportAsUSDZ()
                            } label: {
                                Label("Xuất file Apple USDZ (.usdz có Texture)", systemImage: "arkit")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
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
            // SceneKit Interactive View
            SceneKitContainer(
                vertices: viewModel.scanSession.finalVertices,
                normals: viewModel.scanSession.finalNormals,
                texCoords: viewModel.scanSession.finalTexCoords,
                indices: viewModel.scanSession.finalIndices,
                texture: viewModel.scanSession.finalTexture,
                renderMode: renderMode
            )
            .ignoresSafeArea(edges: .top)

            // Bottom Controls & Info Bar
            VStack(spacing: 12) {
                // Render Mode Switcher
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RenderMode.allCases) { mode in
                            Button {
                                renderMode = mode
                                HapticManager.shared.selection()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: mode.systemImage)
                                    Text(mode.rawValue)
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(renderMode == mode ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    renderMode == mode ? Color.cyan : Color.white.opacity(0.12),
                                    in: Capsule()
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Stats Bar
                HStack {
                    Label(
                        "\(viewModel.scanSession.finalVertices.count) đỉnh",
                        systemImage: "circle.grid.3x3"
                    )
                    Spacer()
                    Label(
                        "\(viewModel.scanSession.finalIndices.count / 3) tam giác",
                        systemImage: "triangle"
                    )
                    Spacer()
                    Label(
                        viewModel.scanSession.finalTexture != nil ? "Texture HD" : "3D Mesh",
                        systemImage: "photo.fill"
                    )
                    Spacer()
                    Label("Xoay 360°", systemImage: "hand.pinch")
                }
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
            .padding(.top, 10)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.gray.opacity(0.4))

            Text("Chưa có dữ liệu 3D")
                .font(.title3.bold())
                .foregroundStyle(.gray)

            Text("Hãy sang tab Scanner và hoàn thành\nquét khuôn mặt để xem mô hình 3D.")
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
            indices: session.finalIndices,
            texture: session.finalTexture
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
            indices: session.finalIndices,
            texture: session.finalTexture
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
/// Supports high-resolution texture mapping from the user's real face, double-sided rendering, and studio lighting.
struct SceneKitContainer: UIViewRepresentable {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let texCoords: [SIMD2<Float>]
    let indices: [Int16]
    let texture: UIImage?
    var renderMode: RenderMode = .textured

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = buildScene()
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling4X
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = buildScene()
    }

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        guard !vertices.isEmpty, !indices.isEmpty else { return scene }

        // Vertex Positions
        let positions = vertices.map { SCNVector3($0.x, $0.y, $0.z) }
        let positionSource = SCNGeometrySource(vertices: positions)

        // Vertex Normals
        let normalVectors: [SCNVector3]
        if normals.count == vertices.count {
            normalVectors = normals.map { SCNVector3($0.x, $0.y, $0.z) }
        } else {
            normalVectors = positions
        }
        let normalSource = SCNGeometrySource(normals: normalVectors)

        // Texture Coordinates (UV mapping)
        let texCoordSource = SCNGeometrySource(
            textureCoordinates: texCoords.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1.0 - $0.y)) }
        )

        // Geometry Element (Triangles)
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

        // Material Configuration
        let material = SCNMaterial()
        material.isDoubleSided = true

        switch renderMode {
        case .textured:
            if let texture = texture {
                material.diffuse.contents = texture
                material.roughness.contents = NSNumber(value: 0.6)
                material.specular.contents = UIColor(white: 0.2, alpha: 1.0)
                material.lightingModel = .phong
            } else {
                material.diffuse.contents = UIColor(red: 0.88, green: 0.76, blue: 0.67, alpha: 1.0)
                material.lightingModel = .phong
            }
            material.fillMode = .fill

        case .hybrid:
            if let texture = texture {
                material.diffuse.contents = texture
            } else {
                material.diffuse.contents = UIColor(red: 0.88, green: 0.76, blue: 0.67, alpha: 1.0)
            }
            material.lightingModel = .phong
            material.fillMode = .fill

        case .clay:
            material.diffuse.contents = UIColor(red: 0.75, green: 0.72, blue: 0.70, alpha: 1.0)
            material.specular.contents = UIColor(white: 0.4, alpha: 1.0)
            material.roughness.contents = NSNumber(value: 0.4)
            material.lightingModel = .physicallyBased
            material.fillMode = .fill

        case .wireframe:
            material.diffuse.contents = UIColor.cyan
            material.lightingModel = .constant
            material.fillMode = .lines
        }

        geometry.materials = [material]

        let meshNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(meshNode)

        // In Hybrid mode: Add a second overlay wireframe node
        if renderMode == .hybrid {
            let wireMaterial = SCNMaterial()
            wireMaterial.diffuse.contents = UIColor.cyan.withAlphaComponent(0.6)
            wireMaterial.lightingModel = .constant
            wireMaterial.fillMode = .lines
            wireMaterial.isDoubleSided = true

            let wireGeometry = SCNGeometry(
                sources: [positionSource, normalSource, texCoordSource],
                elements: [element]
            )
            wireGeometry.materials = [wireMaterial]
            let wireNode = SCNNode(geometry: wireGeometry)
            wireNode.scale = SCNVector3(1.002, 1.002, 1.002) // Slight offset to prevent Z-fighting
            scene.rootNode.addChildNode(wireNode)
        }

        // Camera Node setup
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 10.0
        cameraNode.position = SCNVector3(0, 0, 0.35)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Studio Lighting
        addStudioLighting(to: scene)

        return scene
    }

    private func addStudioLighting(to scene: SCNScene) {
        // Omnidirectional light at front
        let omni = SCNNode()
        omni.light = SCNLight()
        omni.light?.type = .omni
        omni.light?.intensity = 1100
        omni.light?.color = UIColor.white
        omni.position = SCNVector3(0, 0, 0.5)
        scene.rootNode.addChildNode(omni)

        // Key light (warm, upper right)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyLight)

        // Fill light (cool, lower left)
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 500
        fillLight.light?.color = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fillLight)

        // Ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 600
        ambient.light?.color = UIColor(white: 0.7, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)
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
