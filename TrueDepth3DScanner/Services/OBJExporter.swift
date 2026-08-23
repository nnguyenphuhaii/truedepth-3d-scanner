import Foundation

/// Exports face mesh data to Wavefront OBJ format with a companion MTL material file.
/// OBJ is a widely supported 3D format compatible with Blender, Maya, and most 3D tools.
final class OBJExporter {

    /// Export vertices, normals, texture coordinates, and triangle indices to an OBJ file.
    /// Returns the URL of the generated `.obj` file, or `nil` on failure.
    static func export(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texCoords: [SIMD2<Float>],
        indices: [Int16]
    ) -> URL? {
        let logger = LoggerService.shared

        guard !vertices.isEmpty else {
            logger.log("OBJ export failed: no vertices", level: .error)
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())

        var obj = "# TrueDepth 3D Face Scanner - OBJ Export\n"
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

        // Texture coordinates
        for t in texCoords {
            obj += String(format: "vt %.6f %.6f\n", t.x, t.y)
        }
        obj += "\n"

        // Normals
        for n in normals {
            obj += String(format: "vn %.6f %.6f %.6f\n", n.x, n.y, n.z)
        }
        obj += "\n"

        // Faces (OBJ uses 1-based indexing)
        obj += "usemtl FaceMaterial\n"
        let triangleCount = indices.count / 3
        for i in 0..<triangleCount {
            let i0 = Int(indices[i * 3]) + 1
            let i1 = Int(indices[i * 3 + 1]) + 1
            let i2 = Int(indices[i * 3 + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        // Material file
        let mtl = """
        # TrueDepth 3D Face Scanner - Material
        newmtl FaceMaterial
        Ka 0.20 0.20 0.20
        Kd 0.85 0.75 0.65
        Ks 0.30 0.30 0.30
        Ns 50.0
        d 1.0
        illum 2
        """

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceScanExport", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let objURL = tempDir.appendingPathComponent("FaceScan.obj")
            let mtlURL = tempDir.appendingPathComponent("FaceScan.mtl")
            try obj.write(to: objURL, atomically: true, encoding: .utf8)
            try mtl.write(to: mtlURL, atomically: true, encoding: .utf8)
            logger.log("OBJ exported to \(objURL.lastPathComponent) (\(vertices.count) verts)", level: .info)
            return objURL
        } catch {
            logger.log("OBJ export write failed: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
}
