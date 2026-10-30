import 'dart:math' as math;

class EmbeddingAggregator {
  /// --------------------------------------------------------------------------
  /// 3. AVERAGE EMBEDDING VECTORS (MEAN TEMPLATE)
  /// --------------------------------------------------------------------------
  /// Takes multiple embeddings collected during registration (e.g., center, left, right),
  /// averages them element-wise, and applies L2 normalization.
  static List<double> computeNormalizedMeanEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw ArgumentError('Embedding list cannot be empty.');
    }

    final int dim = embeddings.first.length;
    final List<double> meanVector = List.filled(dim, 0.0);

    // 1. Element-wise summation
    for (final embedding in embeddings) {
      if (embedding.length != dim) {
        throw ArgumentError('All embeddings must have the same dimension ($dim).');
      }
      for (int i = 0; i < dim; i++) {
        meanVector[i] += embedding[i];
      }
    }

    // 2. Average elements
    final int count = embeddings.length;
    for (int i = 0; i < dim; i++) {
      meanVector[i] /= count;
    }

    // 3. Compute L2 Norm (Euclidean Norm)
    double sumOfSquares = 0.0;
    for (int i = 0; i < dim; i++) {
      sumOfSquares += meanVector[i] * meanVector[i];
    }
    double l2Norm = math.sqrt(sumOfSquares);

    // 4. L2 Normalize (with division-by-zero protection)
    if (l2Norm > 1e-12) {
      for (int i = 0; i < dim; i++) {
        meanVector[i] /= l2Norm;
      }
    }

    return meanVector;
  }
}