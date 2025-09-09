import CoreImage
import UIKit

// MARK: - Leica LUX Filter Implementation
// Based on official Leica LUX app filters and numerical analysis data

extension FilteredCameraViewController {
    
    func applyLeicaFilter(to inputImage: CIImage) -> CIImage {
        switch selectedFilter {
            
        // MARK: - Leica LUX Core Looks
        
        case .leicaStandard:
            // Balanced, versatile aesthetic with natural integrity
            // CSV Data: Color Temp -300K, RGB: R-10 G-3 B+4, Contrast -5%, Saturation -2%
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.0
            colorControls.contrast = 0.95  // -5% contrast
            colorControls.saturation = 0.98  // -2% saturation
            
            // Temperature shift -300K (6500 -> 6200)
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 6200, y: 0)
            
            // RGB Shift using color matrix
            let colorMatrix = CIFilter.colorMatrix()
            colorMatrix.inputImage = temperatureAndTint.outputImage
            colorMatrix.rVector = CIVector(x: 0.92, y: 0, z: 0, w: 0)     // R: -10 units
            colorMatrix.gVector = CIVector(x: 0, y: 0.976, z: 0, w: 0)    // G: -3 units
            colorMatrix.bVector = CIVector(x: 0, y: 0, z: 1.03, w: 0)     // B: +4 units
            colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            
            // Shadow/Highlight adjustment +0.3/-0.2 EV
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = colorMatrix.outputImage
            highlightShadow.highlightAmount = 0.8  // -0.2 EV
            highlightShadow.shadowAmount = 0.3     // +0.3 EV
            
            return highlightShadow.outputImage ?? inputImage
            
        case .leicaVivid:
            // Enhanced contrast and vibrancy for impactful images
            // CSV Data: Color Temp +300K, RGB: R+10 G+4 B-3, Contrast +15%, Saturation +8%
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.0
            colorControls.contrast = 1.15   // +15% contrast
            colorControls.saturation = 1.08  // +8% saturation
            
            // Temperature shift +300K (6500 -> 6800)
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 6800, y: 0)
            
            // RGB Shift for vivid colors
            let colorMatrix = CIFilter.colorMatrix()
            colorMatrix.inputImage = temperatureAndTint.outputImage
            colorMatrix.rVector = CIVector(x: 1.08, y: 0, z: 0, w: 0)     // R: +10 units
            colorMatrix.gVector = CIVector(x: 0, y: 1.03, z: 0, w: 0)     // G: +4 units
            colorMatrix.bVector = CIVector(x: 0, y: 0, z: 0.976, w: 0)    // B: -3 units
            colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            
            // Gamma adjustment for punch
            let gammaAdjust = CIFilter.gammaAdjust()
            gammaAdjust.inputImage = colorMatrix.outputImage
            gammaAdjust.power = 2.3 / 2.2  // Gamma from 2.2 to 2.3
            
            // Shadow/Highlight +0.1/-0.3 EV
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = gammaAdjust.outputImage
            highlightShadow.highlightAmount = 0.7  // -0.3 EV
            highlightShadow.shadowAmount = 0.1     // +0.1 EV
            
            return highlightShadow.outputImage ?? inputImage
            
        case .leicaNatural:
            // Genuine emotion with softened saturation and smooth tones
            // CSV Data: Color Temp -200K, RGB: R-6 G0 B+2, Contrast -15%, Saturation -12%
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.0
            colorControls.contrast = 0.85   // -15% contrast
            colorControls.saturation = 0.88  // -12% saturation
            
            // Temperature shift -200K (6500 -> 6300)
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 6300, y: 0)
            
            // RGB Shift for natural tones
            let colorMatrix = CIFilter.colorMatrix()
            colorMatrix.inputImage = temperatureAndTint.outputImage
            colorMatrix.rVector = CIVector(x: 0.953, y: 0, z: 0, w: 0)    // R: -6 units
            colorMatrix.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0)      // G: 0 units
            colorMatrix.bVector = CIVector(x: 0, y: 0, z: 1.016, w: 0)    // B: +2 units
            colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            
            // Flatter gamma for editable foundation
            let gammaAdjust = CIFilter.gammaAdjust()
            gammaAdjust.inputImage = colorMatrix.outputImage
            gammaAdjust.power = 2.0 / 2.2  // Gamma from 2.2 to 2.0
            
            // Gentle tone mapping +0.2/-0.1 EV
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = gammaAdjust.outputImage
            highlightShadow.highlightAmount = 0.9  // -0.1 EV
            highlightShadow.shadowAmount = 0.2    // +0.2 EV
            
            return highlightShadow.outputImage ?? inputImage
            
        case .leicaClassic:
            // Analog, cinematic look with warm, washed-out colors
            // CSV Data: Color Temp -700K, Contrast +10%, Saturation +5%, Gamma +0.2, Grain 15
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.03
            colorControls.contrast = 1.10   // +10% contrast
            colorControls.saturation = 1.05  // +5% saturation for enhanced warmth
            
            // Strong warm temperature shift -700K (6500 -> 5800)
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 5800, y: 3)
            
            // Film-like gamma curve
            let gammaAdjust = CIFilter.gammaAdjust()
            gammaAdjust.inputImage = temperatureAndTint.outputImage
            gammaAdjust.power = 2.4 / 2.2  // Gamma from 2.2 to 2.4
            
            // Add subtle sepia tone for vintage feel
            let sepiaTone = CIFilter.sepiaTone()
            sepiaTone.inputImage = gammaAdjust.outputImage
            sepiaTone.intensity = 0.05
            
            // Strong film emulation +0.4/-0.3 EV
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = sepiaTone.outputImage
            highlightShadow.highlightAmount = 0.7  // -0.3 EV
            highlightShadow.shadowAmount = 0.4    // +0.4 EV
            
            // Classic vignette
            let vignette = CIFilter.vignette()
            vignette.inputImage = highlightShadow.outputImage
            vignette.intensity = 0.4
            vignette.radius = 1.6
            
            return vignette.outputImage ?? inputImage
            
        case .leicaContemporary:
            // Modern aesthetic with balanced tones
            // CSV Data: Color Temp -100K, Contrast +5%, Saturation +2%, Gamma 0.0
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.02
            colorControls.contrast = 1.05   // +5% contrast
            colorControls.saturation = 1.02  // +2% saturation
            
            // Subtle temperature shift -100K (6500 -> 6400)
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 6400, y: 2)
            
            // Balanced exposure recovery +0.2/-0.2 EV
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = temperatureAndTint.outputImage
            highlightShadow.highlightAmount = 0.8  // -0.2 EV
            highlightShadow.shadowAmount = 0.2    // +0.2 EV
            
            // Subtle vignette
            let vignette = CIFilter.vignette()
            vignette.inputImage = highlightShadow.outputImage
            vignette.intensity = 0.2
            vignette.radius = 2.0
            
            return vignette.outputImage ?? inputImage
            
        case .leicaEternal:
            // Bold, stylized look with magenta tint
            // CSV Data: Color Temp +100K, Contrast +25%, Grain 20
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.02
            colorControls.contrast = 1.25   // +25% contrast
            colorControls.saturation = 1.15
            
            // Cool temperature shift +100K (6500 -> 6600)
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 6600, y: -8)  // Magenta tint
            
            // Add vibrance for bold look
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = temperatureAndTint.outputImage
            vibrance.amount = 0.5
            
            // Strong vignette for dramatic effect
            let vignette = CIFilter.vignette()
            vignette.inputImage = vibrance.outputImage
            vignette.intensity = 0.45
            vignette.radius = 1.5
            
            return vignette.outputImage ?? inputImage
            
        // MARK: - Leica Black & White Looks
        
        case .leicaBWNatural:
            // Classic B&W with good tonal range
            // CSV Data: Luminance -5%, natural tonal range
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.02
            colorControls.contrast = 1.1
            colorControls.saturation = 0  // Convert to B&W
            
            // Adjust luminance
            let exposure = CIFilter.exposureAdjust()
            exposure.inputImage = colorControls.outputImage
            exposure.ev = -0.15  // -5% luminance
            
            // Add film grain for authentic B&W look
            let noiseReduction = CIFilter.noiseReduction()
            noiseReduction.inputImage = exposure.outputImage
            noiseReduction.noiseLevel = 0.02
            noiseReduction.sharpness = 0.8
            
            // Subtle vignette
            let vignette = CIFilter.vignette()
            vignette.inputImage = noiseReduction.outputImage
            vignette.intensity = 0.3
            vignette.radius = 1.8
            
            return vignette.outputImage ?? inputImage
            
        case .leicaBWHighContrast:
            // High contrast B&W with dramatic shadows
            // CSV Data: Luminance -15%, high contrast
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.05
            colorControls.contrast = 1.35  // High contrast
            colorControls.saturation = 0  // Convert to B&W
            
            // Strong luminance reduction
            let exposure = CIFilter.exposureAdjust()
            exposure.inputImage = colorControls.outputImage
            exposure.ev = -0.45  // -15% luminance
            
            // Sharpen for crisp B&W look
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = exposure.outputImage
            sharpen.sharpness = 0.5
            sharpen.radius = 1.5
            
            // Strong vignette for dramatic effect
            let vignette = CIFilter.vignette()
            vignette.inputImage = sharpen.outputImage
            vignette.intensity = 0.6
            vignette.radius = 1.2
            
            return vignette.outputImage ?? inputImage
            
        // MARK: - Artist Look Series
        
        case .gregWilliams:
            // Cinematic, newspaper-like aesthetic inspired by Tri-X 400
            // CSV Data: Contrast +40%, Film Grain 25
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.03
            colorControls.contrast = 1.40  // +40% contrast
            colorControls.saturation = 0.85  // Slightly desaturated
            
            // Warm, documentary feel
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 5900, y: 4)
            
            // Enhanced micro-contrast
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = temperatureAndTint.outputImage
            sharpen.sharpness = 0.4
            sharpen.radius = 2.0
            
            // Deep shadows for cinematic look
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = sharpen.outputImage
            highlightShadow.highlightAmount = 0.6
            highlightShadow.shadowAmount = 0.5
            
            // Strong vignette for focus
            let vignette = CIFilter.vignette()
            vignette.inputImage = highlightShadow.outputImage
            vignette.intensity = 0.55
            vignette.radius = 1.3
            
            return vignette.outputImage ?? inputImage
            
        // MARK: - Lens Simulations
        
        case .summilux28mm:
            // Summilux-M 28mm f/1.4 ASPH simulation
            // CSV Data: Vignetting +10%, Bokeh Radius +13px
            return applyLensSimulation(to: inputImage, 
                                      vignetting: 0.12,  // 12% vignetting
                                      bokehRadius: 28,
                                      warmth: 100)
            
        case .summilux35mm:
            // Summilux-M 35mm f/1.4 ASPH simulation
            // CSV Data: Vignetting +16%, Bokeh Radius +20px
            return applyLensSimulation(to: inputImage,
                                      vignetting: 0.18,  // 18% vignetting
                                      bokehRadius: 35,
                                      warmth: 150)
            
        case .noctilux50mm:
            // Noctilux-M 50mm f/0.95 ASPH simulation
            // CSV Data: Vignetting +23%, Bokeh Radius +30px, distinctive swirly bokeh
            return applyNoctiluxSimulation(to: inputImage)
            
        case .apoTelyt135mm:
            // APO-Telyt-M 135mm f/3.4 simulation
            // CSV Data: Vignetting +6%, Bokeh Radius +7px, clean telephoto blur
            return applyLensSimulation(to: inputImage,
                                      vignetting: 0.08,  // 8% vignetting
                                      bokehRadius: 22,
                                      warmth: 50)
        }
    }
    
    // MARK: - Helper Functions
    
    private func applyLensSimulation(to inputImage: CIImage, 
                                    vignetting: Float,
                                    bokehRadius: Float,
                                    warmth: Float) -> CIImage {
        // Apply subtle warmth
        let temperatureAndTint = CIFilter.temperatureAndTint()
        temperatureAndTint.inputImage = inputImage
        temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
        temperatureAndTint.targetNeutral = CIVector(x: 6500 - CGFloat(warmth), y: 0)
        
        // Apply vignetting
        let vignette = CIFilter.vignette()
        vignette.inputImage = temperatureAndTint.outputImage ?? inputImage
        vignette.intensity = vignetting
        vignette.radius = 1.5 + Float(bokehRadius / 100)
        
        // Enhance micro-contrast (Leica signature)
        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = vignette.outputImage
        highlightShadow.highlightAmount = 0.85
        highlightShadow.shadowAmount = 0.15
        
        return highlightShadow.outputImage ?? inputImage
    }
    
    private func applyNoctiluxSimulation(to inputImage: CIImage) -> CIImage {
        // Noctilux distinctive rendering
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = inputImage
        colorControls.brightness = 0.02
        colorControls.contrast = 1.08
        colorControls.saturation = 1.05
        
        // Warm characteristic
        let temperatureAndTint = CIFilter.temperatureAndTint()
        temperatureAndTint.inputImage = colorControls.outputImage
        temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
        temperatureAndTint.targetNeutral = CIVector(x: 6200, y: 3)
        
        // Strong vignetting (23%)
        let vignette = CIFilter.vignette()
        vignette.inputImage = temperatureAndTint.outputImage
        vignette.intensity = 0.25
        vignette.radius = 1.8
        
        // Add "Leica Glow" - subtle bloom effect
        let bloom = CIFilter.bloom()
        bloom.inputImage = vignette.outputImage
        bloom.intensity = 0.15
        bloom.radius = 10
        
        // Enhance micro-contrast
        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = bloom.outputImage
        highlightShadow.highlightAmount = 0.9
        highlightShadow.shadowAmount = 0.2
        
        return highlightShadow.outputImage ?? inputImage
    }
}