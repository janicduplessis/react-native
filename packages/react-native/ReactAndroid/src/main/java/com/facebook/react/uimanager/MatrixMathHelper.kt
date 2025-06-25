/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.facebook.react.uimanager

import com.facebook.infer.annotation.Assertions
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * Provides helper methods for converting transform operations into a matrix and then into a list of
 * translate, scale and rotate commands.
 */
public object MatrixMathHelper {
  private const val EPSILON = 1e-5
  private const val RAD_TO_DEG = 180.0 / Math.PI

  private val matrix = Array(4) { DoubleArray(4) }
  private val row = Array(3) { DoubleArray(3) }
  private val perspectiveMatrix = DoubleArray(16)
  private val inverseMatrix = DoubleArray(16)
  private val transposedMatrix = DoubleArray(16)
  private val rightHandSide = DoubleArray(4)

  private inline fun isZero(d: Double): Boolean = d > -1e-8 && d < 1e-8

  @JvmStatic
  public fun multiplyInto(out: DoubleArray, a: DoubleArray, b: DoubleArray) {
    val a00 = a[0]
    val a01 = a[1]
    val a02 = a[2]
    val a03 = a[3]
    val a10 = a[4]
    val a11 = a[5]
    val a12 = a[6]
    val a13 = a[7]
    val a20 = a[8]
    val a21 = a[9]
    val a22 = a[10]
    val a23 = a[11]
    val a30 = a[12]
    val a31 = a[13]
    val a32 = a[14]
    val a33 = a[15]
    var b0 = b[0]
    var b1 = b[1]
    var b2 = b[2]
    var b3 = b[3]
    out[0] = b0 * a00 + b1 * a10 + b2 * a20 + b3 * a30
    out[1] = b0 * a01 + b1 * a11 + b2 * a21 + b3 * a31
    out[2] = b0 * a02 + b1 * a12 + b2 * a22 + b3 * a32
    out[3] = b0 * a03 + b1 * a13 + b2 * a23 + b3 * a33
    b0 = b[4]
    b1 = b[5]
    b2 = b[6]
    b3 = b[7]
    out[4] = b0 * a00 + b1 * a10 + b2 * a20 + b3 * a30
    out[5] = b0 * a01 + b1 * a11 + b2 * a21 + b3 * a31
    out[6] = b0 * a02 + b1 * a12 + b2 * a22 + b3 * a32
    out[7] = b0 * a03 + b1 * a13 + b2 * a23 + b3 * a33
    b0 = b[8]
    b1 = b[9]
    b2 = b[10]
    b3 = b[11]
    out[8] = b0 * a00 + b1 * a10 + b2 * a20 + b3 * a30
    out[9] = b0 * a01 + b1 * a11 + b2 * a21 + b3 * a31
    out[10] = b0 * a02 + b1 * a12 + b2 * a22 + b3 * a32
    out[11] = b0 * a03 + b1 * a13 + b2 * a23 + b3 * a33
    b0 = b[12]
    b1 = b[13]
    b2 = b[14]
    b3 = b[15]
    out[12] = b0 * a00 + b1 * a10 + b2 * a20 + b3 * a30
    out[13] = b0 * a01 + b1 * a11 + b2 * a21 + b3 * a31
    out[14] = b0 * a02 + b1 * a12 + b2 * a22 + b3 * a32
    out[15] = b0 * a03 + b1 * a13 + b2 * a23 + b3 * a33
  }

  /** @param transformMatrix 16-element array of numbers representing 4x4 transform matrix */
  @JvmStatic
  public fun decomposeMatrix(matrixInput: DoubleArray, ctx: MatrixDecompositionContext) {
    if (matrixInput.size != 16 || isZero(matrixInput[15])) return

    val scale = ctx.scale
    val skew = ctx.skew
    val translation = ctx.translation
    val rotation = ctx.rotationDegrees
    val perspective = ctx.perspective

    // Normalize matrix and setup perspectiveMatrix
    for (i in 0..3) {
      for (j in 0..3) {
        val value = matrixInput[i * 4 + j] / matrixInput[15]
        matrix[i][j] = value
        perspectiveMatrix[i * 4 + j] = if (j == 3) 0.0 else value
      }
    }
    perspectiveMatrix[15] = 1.0

    if (isZero(determinant(perspectiveMatrix))) return

    // Handle perspective
    if (!isZero(matrix[0][3]) || !isZero(matrix[1][3]) || !isZero(matrix[2][3])) {
      rightHandSide[0] = matrix[0][3]
      rightHandSide[1] = matrix[1][3]
      rightHandSide[2] = matrix[2][3]
      rightHandSide[3] = matrix[3][3]

      inverse(perspectiveMatrix, inverseMatrix)
      transpose(inverseMatrix, transposedMatrix)
      multiplyVectorByMatrix(rightHandSide, transposedMatrix, perspective)
    } else {
      perspective[0] = 0.0
      perspective[1] = 0.0
      perspective[2] = 0.0
      perspective[3] = 1.0
    }

    // Extract translation
    translation[0] = matrix[3][0]
    translation[1] = matrix[3][1]
    translation[2] = matrix[3][2]

    // Rows from 3x3 upper-left
    for (i in 0..2) {
      row[i][0] = matrix[i][0]
      row[i][1] = matrix[i][1]
      row[i][2] = matrix[i][2]
    }

    // Scale X and normalize row 0
    val len0 = v3Length(row[0])
    scale[0] = len0
    v3NormalizeInPlace(row[0], len0)

    // Skew XY
    skew[0] = v3Dot(row[0], row[1])
    v3CombineInPlace(row[1], row[0], 1.0, -skew[0])

    val len1 = v3Length(row[1])
    scale[1] = len1
    v3NormalizeInPlace(row[1], len1)
    skew[0] /= len1

    // Skew XZ, YZ
    skew[1] = v3Dot(row[0], row[2])
    v3CombineInPlace(row[2], row[0], 1.0, -skew[1])
    skew[2] = v3Dot(row[1], row[2])
    v3CombineInPlace(row[2], row[1], 1.0, -skew[2])

    val len2 = v3Length(row[2])
    scale[2] = len2
    v3NormalizeInPlace(row[2], len2)
    skew[1] /= len2
    skew[2] /= len2

    // Check for coordinate system flip
    val pdum3 = v3Cross(row[1], row[2])
    if (v3Dot(row[0], pdum3) < 0.0) {
      for (i in 0..2) {
        scale[i] *= -1.0
        for (j in 0..2) row[i][j] *= -1.0
      }
    }

    // Rotation (degrees)
    rotation[0] = -atan2(row[2][1], row[2][2]) * RAD_TO_DEG
    rotation[1] = -atan2(-row[2][0], sqrt(row[2][1] * row[2][1] + row[2][2] * row[2][2])) * RAD_TO_DEG
    rotation[2] = -atan2(row[1][0], row[0][0]) * RAD_TO_DEG
  }

  private inline fun v3Length(v: DoubleArray): Double = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])

  private fun v3NormalizeInPlace(v: DoubleArray, len: Double) {
    val inv = 1.0 / len
    v[0] *= inv
    v[1] *= inv
    v[2] *= inv
  }

  private fun v3Dot(a: DoubleArray, b: DoubleArray): Double = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

  private fun v3CombineInPlace(a: DoubleArray, b: DoubleArray, aScale: Double, bScale: Double) {
    a[0] = aScale * a[0] + bScale * b[0]
    a[1] = aScale * a[1] + bScale * b[1]
    a[2] = aScale * a[2] + bScale * b[2]
  }

  private fun v3Cross(a: DoubleArray, b: DoubleArray): DoubleArray =
    doubleArrayOf(
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0]
    )

  @JvmStatic
  public fun determinant(matrix: DoubleArray): Double {
    val m00 = matrix[0]
    val m01 = matrix[1]
    val m02 = matrix[2]
    val m03 = matrix[3]
    val m10 = matrix[4]
    val m11 = matrix[5]
    val m12 = matrix[6]
    val m13 = matrix[7]
    val m20 = matrix[8]
    val m21 = matrix[9]
    val m22 = matrix[10]
    val m23 = matrix[11]
    val m30 = matrix[12]
    val m31 = matrix[13]
    val m32 = matrix[14]
    val m33 = matrix[15]
    return (m03 * m12 * m21 * m30 - m02 * m13 * m21 * m30 - m03 * m11 * m22 * m30 +
        m01 * m13 * m22 * m30 +
        m02 * m11 * m23 * m30 - m01 * m12 * m23 * m30 - m03 * m12 * m20 * m31 +
        m02 * m13 * m20 * m31 +
        m03 * m10 * m22 * m31 - m00 * m13 * m22 * m31 - m02 * m10 * m23 * m31 +
        m00 * m12 * m23 * m31 +
        m03 * m11 * m20 * m32 - m01 * m13 * m20 * m32 - m03 * m10 * m21 * m32 +
        m00 * m13 * m21 * m32 +
        m01 * m10 * m23 * m32 - m00 * m11 * m23 * m32 - m02 * m11 * m20 * m33 +
        m01 * m12 * m20 * m33 +
        m02 * m10 * m21 * m33 - m00 * m12 * m21 * m33 - m01 * m10 * m22 * m33 +
        m00 * m11 * m22 * m33)
  }

  /**
   * Inverse of a matrix. Multiplying by the inverse is used in matrix math instead of division.
   *
   * Formula from:
   * http://www.euclideanspace.com/maths/algebra/matrix/functions/inverse/fourD/index.htm
   */
  @JvmStatic
  public fun inverse(m: DoubleArray, out: DoubleArray) {
    val det = determinant(m)
    if (isZero(det)) return

    out[0] = m[5]  * m[10] * m[15] - m[5]  * m[11] * m[14] - m[9]  * m[6]  * m[15] +
      m[9]  * m[7]  * m[14] + m[13] * m[6]  * m[11] - m[13] * m[7]  * m[10]
    out[1] = -m[1]  * m[10] * m[15] + m[1]  * m[11] * m[14] + m[9]  * m[2] * m[15] -
      m[9]  * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10]
    out[2] = m[1]  * m[6] * m[15] - m[1]  * m[7] * m[14] - m[5]  * m[2] * m[15] +
      m[5]  * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6]
    out[3] = -m[1]  * m[6] * m[11] + m[1]  * m[7] * m[10] + m[5]  * m[2] * m[11] -
      m[5]  * m[3] * m[10] - m[9]  * m[2] * m[7] + m[9]  * m[3] * m[6]
    out[4] = -m[4]  * m[10] * m[15] + m[4]  * m[11] * m[14] + m[8]  * m[6] * m[15] -
      m[8]  * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10]
    out[5] = m[0]  * m[10] * m[15] - m[0]  * m[11] * m[14] - m[8]  * m[2] * m[15] +
      m[8]  * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10]
    out[6] = -m[0]  * m[6] * m[15] + m[0]  * m[7] * m[14] + m[4]  * m[2] * m[15] -
      m[4]  * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6]
    out[7] = m[0]  * m[6] * m[11] - m[0]  * m[7] * m[10] - m[4]  * m[2] * m[11] +
      m[4]  * m[3] * m[10] + m[8]  * m[2] * m[7] - m[8]  * m[3] * m[6]
    out[8] = m[4]  * m[9] * m[15] - m[4]  * m[11] * m[13] - m[8]  * m[5] * m[15] +
      m[8]  * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9]
    out[9] = -m[0]  * m[9] * m[15] + m[0]  * m[11] * m[13] + m[8]  * m[1] * m[15] -
      m[8]  * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9]
    out[10] = m[0]  * m[5] * m[15] - m[0]  * m[7] * m[13] - m[4]  * m[1] * m[15] +
      m[4]  * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5]
    out[11] = -m[0]  * m[5] * m[11] + m[0]  * m[7] * m[9] + m[4]  * m[1] * m[11] -
      m[4]  * m[3] * m[9] - m[8]  * m[1] * m[7] + m[8]  * m[3] * m[5]
    out[12] = -m[4]  * m[9] * m[14] + m[4]  * m[10] * m[13] + m[8]  * m[5] * m[14] -
      m[8]  * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9]
    out[13] = m[0]  * m[9] * m[14] - m[0]  * m[10] * m[13] - m[8]  * m[1] * m[14] +
      m[8]  * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9]
    out[14] = -m[0]  * m[5] * m[14] + m[0]  * m[6] * m[13] + m[4]  * m[1] * m[14] -
      m[4]  * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5]
    out[15] = m[0]  * m[5] * m[10] - m[0]  * m[6] * m[9] - m[4]  * m[1] * m[10] +
      m[4]  * m[2] * m[9] + m[8]  * m[1] * m[6] - m[8]  * m[2] * m[5]

    for (i in 0..15) out[i] /= det
  }

  /** Turns columns into rows and rows into columns. */
  @JvmStatic
  public fun transpose(src: DoubleArray, dst: DoubleArray) {
    for (i in 0..3) {
      for (j in 0..3) {
        dst[i * 4 + j] = src[j * 4 + i]
      }
    }
  }

  /** Based on: http://tog.acm.org/resources/GraphicsGems/gemsii/unmatrix.c */
  @JvmStatic
  public fun multiplyVectorByMatrix(v: DoubleArray, m: DoubleArray, result: DoubleArray) {
    val vx = v[0]
    val vy = v[1]
    val vz = v[2]
    val vw = v[3]
    result[0] = vx * m[0] + vy * m[4] + vz * m[8] + vw * m[12]
    result[1] = vx * m[1] + vy * m[5] + vz * m[9] + vw * m[13]
    result[2] = vx * m[2] + vy * m[6] + vz * m[10] + vw * m[14]
    result[3] = vx * m[3] + vy * m[7] + vz * m[11] + vw * m[15]
  }

  /** Based on: https://code.google.com/p/webgl-mjs/source/browse/mjs.js */
  @JvmStatic
  public fun v3Normalize(vector: DoubleArray, norm: Double): DoubleArray {
    val im = 1 / if (isZero(norm)) v3Length(vector) else norm
    return doubleArrayOf(vector[0] * im, vector[1] * im, vector[2] * im)
  }

  /**
   * From:
   * http://www.opensource.apple.com/source/WebCore/WebCore-514/platform/graphics/transforms/TransformationMatrix.cpp
   */
  @JvmStatic
  public fun v3Combine(
      a: DoubleArray,
      b: DoubleArray,
      aScale: Double,
      bScale: Double
  ): DoubleArray {
    return doubleArrayOf(
        aScale * a[0] + bScale * b[0], aScale * a[1] + bScale * b[1], aScale * a[2] + bScale * b[2])
  }

  @JvmStatic
  public fun roundTo3Places(n: Double): Double {
    return Math.round(n * 1000.0) * 0.001
  }

  @JvmStatic
  public fun createIdentityMatrix(): DoubleArray {
    val res = DoubleArray(16)
    resetIdentityMatrix(res)
    return res
  }

  @JvmStatic
  public fun degreesToRadians(degrees: Double): Double {
    return degrees * Math.PI / 180
  }

  @JvmStatic
  public fun resetIdentityMatrix(matrix: DoubleArray) {
    matrix[14] = 0.0
    matrix[13] = matrix[14]
    matrix[12] = matrix[13]
    matrix[11] = matrix[12]
    matrix[9] = matrix[11]
    matrix[8] = matrix[9]
    matrix[7] = matrix[8]
    matrix[6] = matrix[7]
    matrix[4] = matrix[6]
    matrix[3] = matrix[4]
    matrix[2] = matrix[3]
    matrix[1] = matrix[2]
    matrix[15] = 1.0
    matrix[10] = matrix[15]
    matrix[5] = matrix[10]
    matrix[0] = matrix[5]
  }

  @JvmStatic
  public fun applyPerspective(m: DoubleArray, perspective: Double) {
    m[11] = -1 / perspective
  }

  @JvmStatic
  public fun applyScaleX(m: DoubleArray, factor: Double) {
    m[0] = factor
  }

  @JvmStatic
  public fun applyScaleY(m: DoubleArray, factor: Double) {
    m[5] = factor
  }

  public fun applyScaleZ(m: DoubleArray, factor: Double) {
    m[10] = factor
  }

  @JvmStatic
  public fun applyTranslate2D(m: DoubleArray, x: Double, y: Double) {
    m[12] = x
    m[13] = y
  }

  @JvmStatic
  public fun applyTranslate3D(m: DoubleArray, x: Double, y: Double, z: Double) {
    m[12] = x
    m[13] = y
    m[14] = z
  }

  @JvmStatic
  public fun applySkewX(m: DoubleArray, radians: Double) {
    m[4] = tan(radians)
  }

  @JvmStatic
  public fun applySkewY(m: DoubleArray, radians: Double) {
    m[1] = tan(radians)
  }

  @JvmStatic
  public fun applyRotateX(m: DoubleArray, radians: Double) {
    m[5] = cos(radians)
    m[6] = sin(radians)
    m[9] = -sin(radians)
    m[10] = cos(radians)
  }

  @JvmStatic
  public fun applyRotateY(m: DoubleArray, radians: Double) {
    m[0] = cos(radians)
    m[2] = -sin(radians)
    m[8] = sin(radians)
    m[10] = cos(radians)
  }

  // http://www.w3.org/TR/css3-transforms/#recomposing-to-a-2d-matrix
  @JvmStatic
  public fun applyRotateZ(m: DoubleArray, radians: Double) {
    m[0] = cos(radians)
    m[1] = sin(radians)
    m[4] = -sin(radians)
    m[5] = cos(radians)
  }

  public open class MatrixDecompositionContext {
    @JvmField public var perspective: DoubleArray = DoubleArray(4)
    @JvmField public var scale: DoubleArray = DoubleArray(3)
    @JvmField public var skew: DoubleArray = DoubleArray(3)
    @JvmField public var translation: DoubleArray = DoubleArray(3)
    @JvmField public var rotationDegrees: DoubleArray = DoubleArray(3)

    public fun reset() {
      resetArray(perspective)
      resetArray(scale)
      resetArray(skew)
      resetArray(translation)
      resetArray(rotationDegrees)
    }

    private companion object {
      private fun resetArray(arr: DoubleArray) {
        for (i in arr.indices) {
          arr[i] = 0.0
        }
      }
    }
  }
}
