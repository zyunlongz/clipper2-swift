# Clipper2-swift

A Swift port of [Clipper2-java](https://github.com/micycle1/Clipper2-java), which itself is a port of the [Clipper2](https://github.com/AngusJohnson/Clipper2) polygon clipping and offsetting library by Angus Johnson.

Clipper2 performs **boolean clipping operations** (intersection, union, difference, XOR) on both closed polygons and open polylines. It also supports **polygon offsetting** (inflating/deflating).

## Features

- Boolean polygon clipping: intersection, union, difference, XOR
- Polygon offsetting (inflate/deflate) with multiple join types (square, round, miter, bevel)
- Fast rectangular clipping with O(n) performance
- Minkowski sum and difference
- Support for both integer (`Int64`) and floating-point (`Double`) coordinates
- PolyTree output for parent-child polygon relationships
- Path simplification (Ramer-Douglas-Peucker)
- Point-in-polygon testing

## Requirements

- Swift 5.9+
- iOS 13.0+ / macOS 10.15+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/zyunlongz/clipper2-swift", from: "1.0.0")
]
```

Then add `"Clipper2"` as a dependency of your target:

```swift
.target(name: "YourTarget", dependencies: ["Clipper2"])
```

### CocoaPods

```ruby
pod 'Clipper2-swift'
```

## Usage

### Boolean Operations

```swift
import Clipper2

// Create subject and clip polygons
let subject: Paths64 = [[
    Point64(0, 0), Point64(100, 0),
    Point64(100, 100), Point64(0, 100)
]]
let clip: Paths64 = [[
    Point64(50, 50), Point64(150, 50),
    Point64(150, 150), Point64(50, 150)
]]

// Intersection
let intersection = Clipper.intersect(subject, clip, .evenOdd)

// Union
let union = Clipper.union(subject, clip, .evenOdd)

// Difference
let difference = Clipper.difference(subject, clip, .evenOdd)

// XOR
let xor = Clipper.xor(subject, clip, .evenOdd)
```

### Polygon Offsetting

```swift
let paths: Paths64 = [[
    Point64(0, 0), Point64(100, 0),
    Point64(100, 100), Point64(0, 100)
]]

// Inflate by 10 units with round joins
let inflated = Clipper.inflatePaths(paths, 10, .round, .polygon)

// Deflate by 5 units with miter joins
let deflated = Clipper.inflatePaths(paths, -5, .miter, .polygon)
```

### Rectangle Clipping

```swift
let rect = Rect64(100, 100, 300, 300)
let paths: Paths64 = [[
    Point64(0, 0), Point64(200, 0),
    Point64(200, 200), Point64(0, 200)
]]

let clipped = Clipper.rectClip(rect, paths)
```

### Using the Engine Directly

```swift
let clipper = Clipper64()
clipper.addSubject(subjectPaths)
clipper.addClip(clipPaths)

var solution: Paths64 = []
clipper.execute(.intersection, .evenOdd, &solution)
```

### Floating-Point Coordinates

```swift
let clipperD = ClipperD(roundingDecimalPrecision: 2)
clipperD.addSubject(subjectPathD)
clipperD.addClip(clipPathD)

var solution: PathsD = []
clipperD.execute(.union, .nonZero, &solution)
```

## API Reference

The main entry point is the `Clipper` enum, which provides static convenience methods for common operations. For more control, use `Clipper64` (integer coordinates) or `ClipperD` (floating-point coordinates) directly.

### Key Types

| Type | Description |
|------|-------------|
| `Point64` | Integer coordinate point (Int64 x, y) |
| `PointD` | Floating-point coordinate point (Double x, y) |
| `Path64` | Array of Point64 (`[Point64]`) |
| `PathD` | Array of PointD (`[PointD]`) |
| `Paths64` | Array of Path64 (`[Path64]`) |
| `PathsD` | Array of PathD (`[PathD]`) |
| `Rect64` | Integer rectangle (left, top, right, bottom) |
| `ClipType` | Boolean operation: `.intersection`, `.union`, `.difference`, `.xor` |
| `FillRule` | Winding rule: `.evenOdd`, `.nonZero`, `.positive`, `.negative` |
| `JoinType` | Offset join: `.square`, `.round`, `.miter`, `.bevel` |
| `EndType` | Offset end: `.polygon`, `.joined`, `.butt`, `.square`, `.round` |

## License

[Boost Software License - Version 1.0](LICENSE)

## Acknowledgments

- [Clipper2](https://github.com/AngusJohnson/Clipper2) by Angus Johnson - the original C# library
- [Clipper2-java](https://github.com/micycle1/Clipper2-java) by Michael Carleton - the Java port this project is based on
