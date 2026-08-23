import Foundation
import UIKit

/// Exports face mesh data and real photo texture to Wavefront OBJ format with companion MTL material file.
/// Fully compatible with Blender, Maya, Unity, Unreal Engine, and WebGL viewers.
final class OBJExporter {

    /// Export vertices, normals, texture coordinates, triangle indices, and photo texture to an OBJ folder.
    /// Returns the URL of the generated `.obj` file, or `nil` on failure.
    static func export(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texCoords: [SIMD2<Float>],
        indices: [Int16],
        texture: UIImage? = nil
    ) -> URL? {
        let logger = LoggerService.shared

        guard !vertices.isEmpty else {
            logger.log("OBJ export failed: no vertices", level: .error)
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceScanExport_\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            logger.log("Failed to create export dir: \(error.localizedDescription)", level: .error)
            return nil
        }

        // 1. Save texture image if present
        var hasTexture = false
        if let texture = texture, let jpegData = texture.jpegData(compressionQuality: 0.9) {
            let textureURL = tempDir.appendingPathComponent("FaceTexture.jpg")
            do {
                try jpegData.write(to: textureURL)
                hasTexture = true
            } catch {
                logger.log("Failed to save texture: \(error.localizedDescription)", level: .warning)
            }
        }

        // 2. Generate MTL file
        var mtl = "# Material definition for FaceScan\n"
        mtl += "newmtl FaceMaterial\n"
        mtl += "Ka 0.2 0.2 0.2\n"
        mtl += "Kd 0.9 0.85 0.8\n"
        mtl += "Ks 0.2 0.2 0.2\n"
        mtl += "Ns 20.0\n"
        mtl += "d 1.0\n"
        mtl += "illum 2\n"
        if hasTexture {
            mtl += "map_Kd FaceTexture.jpg\n"
        }

        let mtlURL = tempDir.appendingPathComponent("FaceScan.mtl")
        do {
            try mtl.write(to: mtlURL, atomically: true, encoding: .utf8)
        } catch {
            logger.log("Failed to write MTL: \(error.localizedDescription)", level: .error)
            return nil
        }

        // 3. Generate OBJ file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())

        var obj = "# TrueDepth 3D Face Scanner - Realistic OBJ Export\n"
        obj += "# Generated: \(dateString)\n"
        obj += "# Vertices: \(vertices.count)\n"
        obj += "# Triangles: \(indices.count / 3)\n"
        obj += "mtllib FaceScan.mtl\n"
        obj += "o FaceMesh\n\n"

        // Vertices
        for v in vertices {
            obj += String(format: "v %.6f %.6f %.6f\n", v.x, v.y, v.z)
        }
        obj += "\n"

        // Texture coordinates (UV)
        for t in texCoords {
            obj += String(format: "vt %.6f %.6f\n", t.x, 1.0 - t.y)
        }
        obj += "\n"

        // Normals
        for n in normals {
            obj += String(format: "vn %.6f %.6f %.6f\n", n.x, n.y, n.z)
        }
        obj += "\n"

        // Faces (1-based index)
        obj += "usemtl FaceMaterial\n"
        let triangleCount = indices.count / 3
        for i in 0..<triangleCount {
            let i0 = Int(indices[i * 3]) + 1
            let i1 = Int(indices[i * 3 + 1]) + 1
            let i2 = Int(indices[i * 3 + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        let objURL = tempDir.appendingPathComponent("FaceScan.obj")
        do {
            try obj.write(to: objURL, atomically: true, encoding: .utf8)
            logger.log("OBJ file written successfully: \(objURL.path)", level: .info)
            return objURL
        } catch {
            logger.log("Failed to write OBJ: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
}
