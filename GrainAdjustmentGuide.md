# Film Grain Adjustment Implementation Guide

## Overview
Film grain simulation in iOS can be achieved using Core Image filters. Real film grain is an emergent effect of the chemical process where light-sensitive silver halide particles of varying sizes create random brightness variations across the image.

## Core Techniques for Grain Simulation

### 1. CIRandomGenerator Method
**Purpose**: Generate random noise patterns as a base for grain effect

**Implementation Approach**:
```swift
// Create random noise generator
let randomFilter = CIFilter.randomGenerator()

// Scale and crop to image size
let noiseImage = randomFilter.outputImage?
    .cropped(to: inputImage.extent)

// Blend with original image using CIBlendWithMask or CISourceOverCompositing
```

### 2. Grain Intensity Control Parameters

#### Key Adjustable Parameters:
- **Grain Amount** (0.0 - 1.0): Controls opacity of grain overlay
- **Grain Size** (1.0 - 5.0): Controls scaling of noise pattern
- **Grain Roughness** (0.0 - 1.0): Controls contrast of grain pattern
- **ISO Simulation** (100 - 6400): Maps to grain intensity

### 3. Advanced Grain Composition

#### Step-by-Step Process:
1. **Generate Base Noise**
   - Use CIRandomGenerator for uniform noise
   - Apply CIGaussianBlur with small radius (0.5-2.0) for softer grain

2. **Adjust Grain Characteristics**
   - Use CIColorControls to adjust contrast/brightness of noise
   - Apply CIAffineTransform to scale grain size

3. **Color Processing**
   - CIColorMonochrome for B&W films
   - Preserve original colors for color films

4. **Blend with Original**
   - CIBlendWithAlphaMask for controlled blending
   - CISourceOverCompositing with adjusted alpha

### 4. ISO-Based Grain Mapping

```
ISO 100-200: grain_intensity = 0.05-0.10
ISO 400-800: grain_intensity = 0.15-0.25
ISO 1600-3200: grain_intensity = 0.30-0.45
ISO 6400+: grain_intensity = 0.50-0.70
```

### 5. Film-Specific Grain Profiles

#### Portra 400 (Fine Grain)
- Grain Amount: 0.12
- Grain Size: 1.2
- Soft, uniform pattern

#### Tri-X 400 (Medium Grain)
- Grain Amount: 0.25
- Grain Size: 1.8
- More pronounced, sharp grain

#### Cinestill 800T (Visible Grain)
- Grain Amount: 0.30
- Grain Size: 2.0
- Tungsten-balanced with halation

#### HP5 Plus 400 (Strong Grain)
- Grain Amount: 0.35
- Grain Size: 2.2
- High contrast B&W grain

### 6. Performance Optimization

#### Techniques:
1. **Pre-generate grain textures** at different intensities
2. **Cache grain patterns** for consistent frame-to-frame appearance
3. **Use lower resolution** for grain calculation, then scale up
4. **Limit grain refresh rate** to 15-30 FPS while maintaining 60 FPS preview

### 7. Implementation Strategy

#### Core Components:
```swift
struct GrainParameters {
    var intensity: Float // 0.0 - 1.0
    var size: Float      // 1.0 - 5.0
    var roughness: Float // 0.0 - 1.0
    var monochrome: Bool // true for B&W grain
}
```

#### Processing Pipeline:
1. Input Image → 
2. Generate/Retrieve Grain Pattern →
3. Scale & Adjust Grain →
4. Blend with Input →
5. Output Image

### 8. User Controls

#### Recommended UI Controls:
- **Grain Slider**: 0-100% intensity
- **ISO Preset Buttons**: Quick selection (100, 400, 800, 1600, 3200)
- **Grain Type Toggle**: Fine/Medium/Coarse
- **Auto-Grain**: Based on lighting conditions

### 9. Real-time Considerations

#### For 60 FPS Performance:
- Use Metal shaders for grain generation
- Implement grain as last step in filter chain
- Consider temporal coherence for video
- Pre-calculate grain masks per frame

### 10. Testing Approach

1. Create reference images with known grain levels
2. Compare visual quality across different devices
3. Measure performance impact (target <5ms per frame)
4. Validate grain consistency across filter changes

## Implementation Notes

The key to realistic grain is:
1. **Randomness with structure** - Not pure noise
2. **Luminance-based application** - Grain affects brightness more than color
3. **Size variation** - Mix different grain sizes
4. **Temporal stability** - Consistent but not static in video

## References
- Core Image Filter Reference (Apple)
- CIRandomGenerator Documentation
- CIColorMonochrome Documentation
- CIBlendWithMask Documentation