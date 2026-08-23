import Foundation
import ModelIO
import SceneKit

/// Exports face mesh data to Apple USDZ format using ModelIO.
/// USDZ is Apple's native 3D format, compatible with Quick Look, Reality Composer, and Blender.
final class USDZExporter {

    /// Export mesh data to a USDZ file.
    /// Falls back to USDA if USDZ export is unavailable on the device.
    /// Returns the URL of the generated file, or `nil` on failure.
    static func export(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texCoords: [SIMD2<Float>],
        indices: [Int16]
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
        let texCoordData = texCoords.withUnsafeBytes { Data($0) }
        let texCoordBuffer = allocator.newBuffer(with: texCoordData, type: .vertex)

        // Build index buffer (convert Int16 to UInt32 for ModelIO)
        let uint32Indices = indices.map { UInt32($0) }
        let indexData = uint32Indices.withUnsafeBytes { Data($0) }
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        // Create submesh
        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: uint32Indices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: createMaterial()
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

        // Export
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceScanExport", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            if MDLAsset.canExportFileExtension("usdz") {
                let usdzURL = tempDir.appendingPathComponent("FaceScan.usdz")
                try asset.export(to: usdzURL)
                logger.log("USDZ exported successfully (\(vertices.count) verts)", level: .info)
                return usdzURL
            } else {
                // Fallback to USDA
                let usdaURL = tempDir.appendingPathComponent("FaceScan.usda")
                try asset.export(to: usdaURL)
                logger.log("Exported as USDA fallback (USDZ unavailable)", level: .warning)
                return usdaURL
            }
        } catch {
            logger.log("USDZ export failed: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    /// Creates a physically plausible material with a skin-tone base color.
    private static func createMaterial() -> MDLMaterial {
        let scattering = MDLPhysicallyPlausibleScatteringFunction()
        let material = MDLMaterial(name: "FaceMaterial", scatteringFunction: scattering)
        let baseColor = MDLMaterialProperty(
            name: "baseColor",
            semantic: .baseColor,
            float3: SIMD3<Float>(0.85, 0.75, 0.65)
        )
        material.setProperty(baseColor)
        return material
    }
}
