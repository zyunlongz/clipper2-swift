/// A callback for calculating a variable delta during polygon offsetting.
///
/// Implementations define how to calculate the delta (the amount of offset)
/// to apply at each point in a polygon during an offset operation. The offset
/// can vary from point to point, allowing for variable offsetting.
///
/// - Parameters:
///   - path: The original polygon path.
///   - pathNorms: The normals of the path.
///   - currPt: The index of the current point.
///   - prevPt: The index of the previous point.
/// - Returns: The calculated delta for the current point.
public typealias DeltaCallback64 = (_ path: Path64, _ pathNorms: PathD, _ currPt: Int, _ prevPt: Int) -> Double
