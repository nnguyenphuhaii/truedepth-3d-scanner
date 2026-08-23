import Foundation
import ModelIO
import SceneKit
import UIKit

/// Exports face mesh data and photo texture to Apple USDZ format using ModelIO.
final class USDZExporter {

    /// Export mesh data to a USDZ file with embedded face texture.
    static func export(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texCoords: [SIMD2<Float>],
        indices: [Int16],
        texture: UIImage? = nil
    ) -> URL? {
        let logger = LoggerService.shared

        guard !vertices.isEmpty else {
            logger.log("USDZ export failed: no vertices", level: .error)
            return nil
        }

        let allocator = MDLMeshBufferDataAllocator()

        // Build vertex buffer
        let vertexData = vertices.withUnsafeBytes { Data($0) }
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        // Build normal buffer
        let normalData = normals.withUnsafeBytes { Data($0) }
        let normalBuffer = allocator.newBuffer(with: normalData, type: .vertex)

        // Build texture coordinate buffer
        let flippedTexCoords = texCoords.map { SIMD2<Float>($0.x, 1.0 - $0.y) }
        let texCoordData = flippedTexCoords.withUnsafeBytes { Data($0) }
        let texCoordBuffer = allocator.newBuffer(with: texCoordData, type: .vertex)

        // Build index buffer (UInt32 for ModelIO)
        let uint32Indices = indices.map { UInt32($0) }
        let indexData = uint32Indices.withUnsafeBytes { Data($0) }
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        // Temp directory for export
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceScanUSDZ_\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            logger.log("Failed to create USDZ temp dir", level: .error)
            return nil
        }

        // Material setup
        let material = MDLMaterial(
            name: "FaceMaterial",
            scatteringFunction: MDLPhysicallyPlausibleScatteringFunction()
        )

        if let texture = texture, let jpegData = texture.jpegData(compressionQuality: 0.9) {
            let textureURL = tempDir.appendingPathComponent("FaceTexture.jpg")
            try? jpegData.write(to: textureURL)

            let textureProp = MDLMaterialProperty(
                name: "baseColor",
                semantic: .baseColor,
                url: textureURL
            )
            material.setProperty(textureProp)
        } else {
            let diffuseColor = MDLMaterialProperty(
                name: "baseColor",
                semantic: .baseColor,
                color: UIColor(red: 0.87, green: 0.77, blue: 0.68, alpha: 1.0).cgColor
            )
            material.setProperty(diffuseColor)
        }

        // Create submesh
        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: uint32Indices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: material
        )

        // Vertex descriptor
        let descriptor = MDLVertexDescriptor()

        let positionAttribute = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        descriptor.attributes[0] = positionAttribute
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)

        let normalAttribute = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: 0,
            bufferIndex: 1
        )
        descriptor.attributes[1] = normalAttribute
        descriptor.layouts[1] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)

        let texCoordAttribute = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: 0,
            bufferIndex: 2
        )
        descriptor.attributes[2] = texCoordAttribute
        descriptor.layouts[2] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD2<Float>>.stride)

        // Create mesh
        let mesh = MDLMesh(
            vertexBuffers: [vertexBuffer, normalBuffer, texCoordBuffer],
            vertexCount: vertices.count,
            descriptor: descriptor,
            submeshes: [submesh]
        )

        // Create asset
        let asset = MDLAsset()
        asset.add(mesh)

        let fileURL = tempDir.appendingPathComponent("FaceScan.usdz")

        do {
            try asset.export(to: fileURL)
            logger.log("USDZ file exported successfully: \(fileURL.path)", level: .info)
            return fileURL
        } catch {
            logger.log("USDZ export failed: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
}
