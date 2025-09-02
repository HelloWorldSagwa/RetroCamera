# Light Leak/Fade Effect Implementation Guide

## Overview
Light leaks are characteristic imperfections from analog film cameras where light accidentally entered the camera body, creating dreamy streaks of colored light. In digital photography, these effects add vintage aesthetic and nostalgic feel.

## Apple Core Image Filters for Light Effects

### 1. Built-in Photo Effect Filters
Apple provides specific vintage photo effect filters (iOS 7.0+):

#### CIPhotoEffectFade
- **Purpose**: Imitates vintage photography film with diminished color
- **Use Case**: Creates faded, washed-out look typical of old photos
- **Parameters**: None (preconfigured effect)

#### CIPhotoEffectTransfer
- **Purpose**: Emphasizes warm colors like vintage film
- **Use Case**: Adds warm orange/red tints similar to light leaks
- **Parameters**: None (preconfigured effect)

#### CIPhotoEffectInstant
- **Purpose**: Distorted colors like instant film
- **Use Case**: Polaroid-style color shifts
- **Parameters**: None (preconfigured effect)

### 2. Gradient Generators for Light Leak Base

#### CIRadialGradient
```swift
// Creates circular light leak from corners/edges
let radialGradient = CIFilter.radialGradient()
radialGradient.center = CGPoint(x: 0, y: imageHeight)
radialGradient.radius0 = 0
radialGradient.radius1 = imageWidth * 0.7
radialGradient.color0 = CIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
radialGradient.color1 = CIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.0)
```

#### CILinearGradient
```swift
// Creates linear light streak
let linearGradient = CIFilter.linearGradient()
linearGradient.point0 = CGPoint(x: 0, y: 0)
linearGradient.point1 = CGPoint(x: imageWidth, y: imageHeight)
linearGradient.color0 = CIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.8)
linearGradient.color1 = CIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.0)
```

### 3. Blend Modes for Light Leak Application

#### CIColorDodgeBlendMode (iOS 6.0+)
- **Effect**: Brightens base image based on blend image
- **Formula**: result = base / (1 - blend)
- **Use**: Creates intense light burst effects

#### CILightenBlendMode (iOS 6.0+)
- **Effect**: Selects lighter of two colors
- **Formula**: result = max(base, blend)
- **Use**: Subtle light overlay without darkening

#### CIScreenBlendMode (iOS 6.0+)
- **Effect**: Inverts, multiplies, inverts again
- **Formula**: result = 1 - (1 - base) * (1 - blend)
- **Use**: Classic light leak blending, preserves highlights

#### CIOverlayBlendMode (iOS 6.0+)
- **Effect**: Combines multiply and screen
- **Use**: Maintains contrast while adding light

### 4. Implementation Strategy

#### Step 1: Create Light Leak Pattern
```swift
struct LightLeakParameters {
    var position: CGPoint      // Origin of leak
    var angle: Float           // Direction of light
    var color: CIColor         // Tint (orange, red, yellow)
    var intensity: Float       // 0.0 - 1.0
    var spread: Float          // How wide the leak spreads
    var type: LeakType        // corner, edge, streak, circular
}

enum LeakType {
    case cornerLeak    // Typical corner light leak
    case edgeStreak    // Along film edge
    case centralBurst  // Center exposure
    case diagonalFlare // Diagonal streak
}
```

#### Step 2: Generate Light Leak
```swift
func generateLightLeak(parameters: LightLeakParameters) -> CIImage {
    // Use radial or linear gradient based on type
    // Apply gaussian blur for softness
    // Add noise for organic feel
    // Apply color tint
}
```

#### Step 3: Composite with Image
```swift
func applyLightLeak(to image: CIImage, leak: CIImage, intensity: Float) -> CIImage {
    // 1. Apply blend mode (Screen or ColorDodge)
    let blended = CIFilter.screenBlendMode()
    blended.inputImage = leak
    blended.backgroundImage = image
    
    // 2. Control intensity with dissolve
    let mixer = CIFilter.dissolveTransition()
    mixer.inputImage = image
    mixer.targetImage = blended.outputImage
    mixer.time = intensity
    
    return mixer.outputImage
}
```

### 5. Realistic Light Leak Characteristics

#### Color Palette
- **Warm Leaks**: Orange (FF9933), Red (FF6666), Yellow (FFCC66)
- **Cool Leaks**: Cyan (66CCFF), Magenta (FF66CC)
- **Vintage Film**: Sepia tones, desaturated oranges

#### Positioning
- **Corner Leaks**: Top-left, bottom-right most common
- **Edge Leaks**: Along film perforations
- **Random Streaks**: Diagonal across frame

#### Intensity Mapping
```
Subtle:   0.1 - 0.2 (barely visible)
Natural:  0.2 - 0.4 (realistic film leak)
Artistic: 0.4 - 0.6 (stylized effect)
Dramatic: 0.6 - 0.8 (heavy effect)
```

### 6. Performance Optimization

#### Techniques:
1. **Pre-generate leak patterns** at app launch
2. **Cache common leak configurations**
3. **Use lower resolution for leak calculation**
4. **Limit to 2-3 leaks per image**
5. **Reuse CIContext for rendering**

### 7. Advanced Effects

#### Animated Light Leaks (Video)
```swift
// Vary intensity over time
intensity = sin(time * frequency) * amplitude + baseline

// Shift position slightly
position.x += sin(time) * wobbleAmount
```

#### Multiple Light Sources
```swift
// Combine multiple leaks
let leak1 = generateCornerLeak()
let leak2 = generateEdgeStreak()
let combined = CIFilter.maximumCompositing()
combined.inputImage = leak1
combined.backgroundImage = leak2
```

### 8. Film-Specific Light Leak Profiles

#### Kodak Portra (Subtle)
- Position: Top corners
- Color: Warm orange (#FF9966)
- Intensity: 0.15-0.25
- Blend: Screen

#### Fuji Superia (Vibrant)
- Position: Diagonal streaks
- Color: Magenta/Cyan mix
- Intensity: 0.25-0.35
- Blend: ColorDodge

#### Lomography (Dramatic)
- Position: Random edges
- Color: Red/Yellow (#FF3333)
- Intensity: 0.40-0.60
- Blend: Overlay

#### Polaroid (Instant)
- Position: Bottom edge
- Color: Yellow fade (#FFFF99)
- Intensity: 0.20-0.30
- Blend: Lighten

### 9. User Controls

#### Recommended UI:
- **Light Leak Toggle**: On/Off
- **Intensity Slider**: 0-100%
- **Position Selector**: Corners/Edges/Random
- **Color Picker**: Warm/Cool/Custom
- **Randomize Button**: Generate random leak

### 10. Testing Considerations

1. Test on different image types (bright/dark/colored)
2. Verify performance impact (<3ms per frame)
3. Check color accuracy across devices
4. Validate natural appearance
5. Test with other filters applied

## Implementation Notes

Key principles for realistic light leaks:
1. **Subtlety is key** - Real leaks are often faint
2. **Color accuracy** - Use film-appropriate colors
3. **Edge placement** - Most leaks occur at film edges
4. **Soft edges** - Always blur for natural look
5. **Layer properly** - Apply after main filter, before grain

## References
- Core Image Filter Reference (Apple)
- CIPhotoEffectFade Documentation
- CIRadialGradient Documentation
- CIColorDodgeBlendMode Documentation
- CIScreenBlendMode Documentation