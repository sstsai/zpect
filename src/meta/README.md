# Meta Type System Architecture

This directory contains the definitions for the "Meta Type" system used in Zpect for protocol parsing and encoding.

## Core Philosophy: Schema vs. Value

The system is built on a strict separation between **Schema** (Metadata) and **Value** (Runtime storage).

### Schema (Metadata)
Schema types are purely declarative. They exist primarily at compile-time to define:
*   **Encoding Rules:** How many bits? Signed or unsigned? String or number?
*   **Semantics:** Is this a temperature? A coordinate? A speed?
*   **Scaling:** How do we convert the raw integer value to a physical quantity?

Schema types **do not** hold runtime data.

### Value (Runtime)
Value types are standard Zig primitives (`u8`, `f64`) or structs that hold the actual decoded data.

### The Role of Codecs
Codecs (located in `src/codec/`) act as the bridge. A codec like `bit_packed` takes a **Schema** type and a **Value** instance (or type) and uses Zig's compile-time reflection to read/write the correct bits and apply transformations.

**Example:**
A generic `decodeStruct` function iterates over the fields of a Schema struct, inspects their metadata (e.g., "this field is 6 bits unsigned"), and populates the corresponding field in the Value struct.

## Current Implementation (`src/meta/schema.zig`)

Currently, `schema.zig` provides the foundational building blocks:

*   `U(bits, T)`: Unsigned integer.
*   `I(bits, T)`: Signed integer.
*   `LatLon(bits)`: Specialized coordinate type with an implicit scale factor (`1/600000`).
*   `Str(bits)`: String type using 6-bit character encoding (common in AIS/NMEA).

## Future Direction: Formalizing Units

We are in the process of replacing ad-hoc scaling (like `LatLon`'s hardcoded scale) with a formalized system for **Quantities** and **Units**.

### Goals
1.  **Type Safety:** Prevent mixing incompatible units (e.g., adding `Meters` to `Seconds` should be a compile error).
2.  **Precision:** Use exact rational arithmetic for scaling factors to avoid floating-point inaccuracies.
3.  **Self-Documentation:** The code should clearly state "This is a speed in Knots" rather than "This is a float scaled by 10".

### Proposed Components

#### 1. `Ratio`
A type for exact rational numbers (Numerator / Denominator). This is crucial for protocols that define scaling factors like `1/10` or `1/600000`.

#### 2. `Dim` (Dimensions)
A compile-time definition of physical dimensions (Length, Time, Mass, Angle, etc.).

#### 3. `Quantity(meta)`
A factory pattern that binds a **Dimension** and a **Unit** to a storage type.

### Architecture Vision

Instead of implicit handling:

```zig
// Current (Implicit)
pub fn LatLon(width: usize) type {
    return struct {
        pub const scale = 600000.0; // Implicit unit, float precision
        ...
    };
}
```

The target architecture uses explicit composition:

```zig
// Future (Explicit)
const Angle = Quantity(.{ .dim = Dim.Angle, .base_unit = Unit.Degree });
const HighResLat = Angle.Variant(.{
    .scale = Ratio.init(1, 600000),
    .encoding = .TwosComplement
});
```

This allows the Codec to query the `Quantity` to understand exactly how to treat the bits, while the rest of the application deals with safe, typed physical quantities.
