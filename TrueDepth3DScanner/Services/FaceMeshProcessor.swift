import Foundation
import simd

/// Processes captured face mesh frames into a single high-accuracy merged mesh.
/// Runs on a background thread to avoid blocking the UI.
final class FaceMeshProcessor {

    /// Merge multiple captured frames into a single refined mesh.
    /// Uses the center frame as the base and blends vertex positions from other angles.
    /// Computes vertex normals from the triangle topology.
    static func processCapturedFrames(_ frames: [CapturedFrame]) async -> (
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texCoords: [SIMD2<Float>],
        indices: [Int16]
    ) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                LoggerService.shared.log("Processing \(frames.count) captured frames", level: .info)

                guard let baseFrame = selectBaseFrame(from: frames) else {
                    LoggerService.shared.log("No frames to process", level: .error)
                    continuation.resume(returning: ([], [], [], []))
                    return
                }

                var mergedVertices = baseFrame.vertices
                let texCoords = baseFrame.textureCoordinates
                let indices = baseFrame.triangleIndices

                // Weighted blending: incorporate vertex data from other directions
                let otherFrames = frames.filter { $0.direction != baseFrame.direction }
                for frame in otherFrames {
                    guard frame.vertices.count == mergedVertices.count else {
                        LoggerService.shared.log(
                            "Vertex count mismatch for direction \(frame.direction.instruction): "
                            + "expected \(mergedVertices.count), got \(frame.vertices.count)",
                            level: .warning
                        )
                        continue
                    }

                    let weight: Float = 0.25
                    for i in 0..<mergedVertices.count {
                        mergedVertices[i] = mergedVertices[i] * (1.0 - weight) + frame.vertices[i] * weight
                    }

                    LoggerService.shared.log(
                        "Blended \(frame.direction.instruction) with weight \(weight)",
                        level: .debug
                    )
                }

                // Compute normals from the merged vertex positions
                let normals = computeNormals(vertices: mergedVertices, indices: indices)

                LoggerService.shared.log(
                    "Mesh processing complete: \(mergedVertices.count) vertices, "
                    + "\(indices.count / 3) triangles",
                    level: .info
                )

                continuation.resume(returning: (mergedVertices, normals, texCoords, indices))
            }
        }
    }

    /// Select the best base frame. Prefers the center direction.
    private static func selectBaseFrame(from frames: [CapturedFrame]) -> CapturedFrame? {
        if let center = frames.first(where: { $0.direction == .center }) {
            return center
        }
        return frames.first
    }

    /// Compute per-vertex normals by averaging face normals of adjacent triangles.
    static func computeNormals(vertices: [SIMD3<Float>], indices: [Int16]) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: vertices.count)

        let triangleCount = indices.count / 3
        for t in 0..<triangleCount {
            let i0 = Int(indices[t * 3])
            let i1 = Int(indices[t * 3 + 1])
            let i2 = Int(indices[t * 3 + 2])

            guard i0 < vertices.count, i1 < vertices.count, i2 < vertices.count else { continue }

            let v0 = vertices[i0]
            let v1 = vertices[i1]
            let v2 = vertices[i2]

            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = simd_cross(edge1, edge2)

            normals[i0] += faceNormal
            normals[i1] += faceNormal
            normals[i2] += faceNormal
        }

        // Normalize all accumulated normals
        for i in 0..<normals.count {
            let length = simd_length(normals[i])
            if length > 0 {
                normals[i] = normals[i] / length
            } else {
                normals[i] = SIMD3<Float>(0, 0, 1)
            }
        }

        return normals
    }
}
