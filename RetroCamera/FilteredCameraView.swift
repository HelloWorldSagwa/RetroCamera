import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import Photos

struct FilteredCameraView: UIViewControllerRepresentable {
    @Binding var selectedFilter: FilmFilter
    @Binding var grainIntensity: Double
    @Binding var lightLeakIntensity: Double
    @Binding var focusPosition: Double
    @Binding var isManualFocus: Bool
    @Binding var bokehIntensity: Double
    @Binding var isSelectiveBokeh: Bool
    @Binding var shouldCapturePhoto: Bool
    @Binding var capturedImage: UIImage?
    @Binding var showDateStamp: Bool
    
    func makeUIViewController(context: Context) -> FilteredCameraViewController {
        let controller = FilteredCameraViewController()
        controller.selectedFilter = selectedFilter
        controller.grainIntensity = Float(grainIntensity)
        controller.lightLeakIntensity = Float(lightLeakIntensity)
        controller.focusPosition = Float(focusPosition)
        controller.isManualFocus = isManualFocus
        controller.bokehIntensity = Float(bokehIntensity)
        controller.isSelectiveBokeh = isSelectiveBokeh
        controller.showDateStamp = showDateStamp
        controller.capturePhotoCompletion = { image in
            capturedImage = image
            shouldCapturePhoto = false
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: FilteredCameraViewController, context: Context) {
        uiViewController.selectedFilter = selectedFilter
        uiViewController.grainIntensity = Float(grainIntensity)
        uiViewController.lightLeakIntensity = Float(lightLeakIntensity)
        uiViewController.focusPosition = Float(focusPosition)
        uiViewController.isManualFocus = isManualFocus
        uiViewController.bokehIntensity = Float(bokehIntensity)
        uiViewController.isSelectiveBokeh = isSelectiveBokeh
        uiViewController.showDateStamp = showDateStamp
        
        if shouldCapturePhoto {
            uiViewController.capturePhoto()
            shouldCapturePhoto = false
        }
    }
}

enum FilmFilter: String, CaseIterable {
    case none = "None"
    case portra400 = "Portra 400"
    case velvia50 = "Velvia 50"
    case tri400 = "Tri-X 400"
    case gold200 = "Gold 200"
    case cinestill800T = "Cinestill 800T"
    case ektachrome = "Ektachrome"
    case fujiSuperia = "Fuji Superia"
    case kodakVision = "Kodak Vision3"
    case ilfordHP5 = "Ilford HP5"
    case agfaVista = "Agfa Vista"
}

class FilteredCameraViewController: UIViewController {
    private var session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let videoOutputQueue = DispatchQueue(label: "video output queue")
    private var isSessionRunning = false
    private var setupResult: SessionSetupResult = .success
    private var ciContext: CIContext!
    private var filterView: UIImageView!
    private var currentVideoInput: AVCaptureDeviceInput?
    private var videoDevicePosition: AVCaptureDevice.Position = .back
    private var cachedLightLeakImage: CIImage?
    private var lastLightLeakGeneration: Date = Date()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var focusIndicatorView: UIView?
    
    var selectedFilter: FilmFilter = .none {
        didSet {
            print("Filter changed to: \(selectedFilter.rawValue)")
        }
    }
    
    var grainIntensity: Float = 0.2 {
        didSet {
            print("Grain intensity changed to: \(grainIntensity)")
        }
    }
    
    var lightLeakIntensity: Float = 0.0 {
        didSet {
            print("Light leak intensity changed to: \(lightLeakIntensity)")
        }
    }
    
    var focusPosition: Float = 0.5 {
        didSet {
            if isManualFocus {
                adjustFocus(to: focusPosition)
            }
        }
    }
    
    var isManualFocus: Bool = false {
        didSet {
            if isManualFocus {
                adjustFocus(to: focusPosition)
            } else {
                resetToAutoFocus()
            }
        }
    }
    
    var bokehIntensity: Float = 0.0 {
        didSet {
            print("Bokeh intensity changed to: \(bokehIntensity)")
        }
    }
    
    var isSelectiveBokeh: Bool = true {
        didSet {
            print("Selective bokeh: \(isSelectiveBokeh)")
        }
    }
    
    var showDateStamp: Bool = false {
        didSet {
            print("Date stamp: \(showDateStamp)")
        }
    }
    
    // Store the last focus point for selective bokeh
    private var lastFocusPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    // Vision request for person segmentation
    private var personSegmentationRequest: VNGeneratePersonSegmentationRequest?
    private var lastPersonMask: CIImage?
    
    // Photo capture
    private var photoOutput: AVCapturePhotoOutput?
    private var lastProcessedImage: CIImage?
    var capturePhotoCompletion: ((UIImage) -> Void)?
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        // Calculate 3:4 aspect ratio frame
        let screenWidth = UIScreen.main.bounds.width
        let cameraHeight = screenWidth * 4.0 / 3.0
        let yOffset = (UIScreen.main.bounds.height - cameraHeight) / 2.0
        
        filterView = UIImageView(frame: CGRect(x: 0, y: yOffset, width: screenWidth, height: cameraHeight))
        filterView.contentMode = .scaleAspectFill
        filterView.clipsToBounds = true
        filterView.isUserInteractionEnabled = true
        view.addSubview(filterView)
        
        // Create preview layer for coordinate conversion
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = filterView.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.isHidden = true  // We don't display it, just use for coordinate conversion
        filterView.layer.addSublayer(previewLayer!)
        
        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        filterView.addGestureRecognizer(tapGesture)
        
        // Create focus indicator view
        focusIndicatorView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusIndicatorView?.layer.borderColor = UIColor.yellow.cgColor
        focusIndicatorView?.layer.borderWidth = 2
        focusIndicatorView?.layer.cornerRadius = 40
        focusIndicatorView?.isHidden = true
        focusIndicatorView?.alpha = 0
        filterView.addSubview(focusIndicatorView!)
        
        ciContext = CIContext(options: [.useSoftwareRenderer: false])
        
        // Setup Vision request for person segmentation (iOS 15+)
        if #available(iOS 15.0, *) {
            setupPersonSegmentation()
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default:
            setupResult = .notAuthorized
        }
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = "RetroCamera doesn't have permission to use the camera."
                    let alertController = UIAlertController(title: "Camera Access", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
                    alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    })
                    self.present(alertController, animated: true)
                }
            case .configurationFailed:
                DispatchQueue.main.async {
                    let message = "Unable to capture media."
                    let alertController = UIAlertController(title: "Camera Error", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
                    self.present(alertController, animated: true)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Maintain 3:4 aspect ratio
        let screenWidth = view.bounds.width
        let cameraHeight = screenWidth * 4.0 / 3.0
        let yOffset = (view.bounds.height - cameraHeight) / 2.0
        filterView.frame = CGRect(x: 0, y: yOffset, width: screenWidth, height: cameraHeight)
        previewLayer?.frame = filterView.bounds
    }
    
    private func adjustFocus(to position: Float) {
        guard let device = currentVideoInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.locked) {
                device.setFocusModeLocked(lensPosition: position) { _ in
                    print("Focus adjusted to position: \(position)")
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error adjusting focus: \(error)")
        }
    }
    
    private func resetToAutoFocus() {
        guard let device = currentVideoInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                print("Reset to auto focus")
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error resetting focus: \(error)")
        }
    }
    
    @objc private func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: filterView)
        
        // Show focus indicator animation
        showFocusIndicator(at: location)
        
        // Convert tap location to device coordinates
        guard let previewLayer = previewLayer else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        
        // Set focus and exposure at the tapped point
        setFocusAndExposure(at: devicePoint)
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        guard let indicator = focusIndicatorView else { return }
        
        // Position the indicator at tap location
        indicator.center = point
        indicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        indicator.alpha = 0
        indicator.isHidden = false
        
        // Animate the focus indicator
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            indicator.transform = CGAffineTransform.identity
            indicator.alpha = 1.0
        }) { _ in
            // Fade out after a delay
            UIView.animate(withDuration: 0.2, delay: 0.5, options: .curveEaseOut, animations: {
                indicator.alpha = 0
            }) { _ in
                indicator.isHidden = true
            }
        }
    }
    
    @available(iOS 15.0, *)
    private func setupPersonSegmentation() {
        personSegmentationRequest = VNGeneratePersonSegmentationRequest()
        personSegmentationRequest?.qualityLevel = .balanced  // Balance between quality and performance
    }
    
    @available(iOS 15.0, *)
    private func generatePersonMask(from pixelBuffer: CVPixelBuffer, completion: @escaping (CIImage?) -> Void) {
        guard let request = personSegmentationRequest else {
            completion(nil)
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                guard let results = request.results,
                      let observation = results.first as? VNPixelBufferObservation else {
                    completion(nil)
                    return
                }
                
                let maskPixelBuffer = observation.pixelBuffer
                let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                
                DispatchQueue.main.async {
                    print("Person mask generated: size \(maskImage.extent)")
                }
                
                completion(maskImage)
            } catch {
                print("Person segmentation error: \(error)")
                completion(nil)
            }
        }
    }
    
    private func setFocusAndExposure(at point: CGPoint) {
        guard let device = currentVideoInput?.device else { return }
        
        // Store the focus point for selective bokeh
        lastFocusPoint = point
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point if supported
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                print("Focus set at point: \(point)")
            }
            
            // Set exposure point if supported
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
                print("Exposure set at point: \(point)")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus/exposure: \(error)")
        }
    }
    
    private func applyDateStamp(to inputImage: CIImage) -> CIImage {
        // Create date string in vintage format (7-segment LCD style)
        let formatter = DateFormatter()
        formatter.dateFormat = "''yy MM dd"  // Format: '95 12 25
        let dateString = formatter.string(from: Date())
        
        // Create the text image with 7-segment LCD style
        let font: UIFont
        // Try different font name variations
        if let dsegFont = UIFont(name: "DSEG7Classic-Bold", size: 20) {
            font = dsegFont
        } else if let dsegFont = UIFont(name: "DSEG7 Classic-Bold", size: 20) {
            font = dsegFont
        } else if let dsegFont = UIFont(name: "DSEG7 Classic", size: 20) {
            font = dsegFont
        } else {
            // Fallback to system monospaced digital font
            font = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 0.95), // Classic orange-red LCD color
            .kern: 2.0 // Add spacing between characters for LCD look
        ]
        
        let textSize = dateString.size(withAttributes: attributes)
        
        // Make sure we have a valid size
        guard textSize.width > 0 && textSize.height > 0 else {
            return inputImage
        }
        
        let renderer = UIGraphicsImageRenderer(size: textSize)
        
        let textImage = renderer.image { context in            
            // Simply draw the date string
            dateString.draw(at: .zero, withAttributes: attributes)
        }
        
        guard let textCIImage = CIImage(image: textImage) else {
            return inputImage
        }
        
        // Position the date stamp in bottom right corner
        // In Core Image, origin (0,0) is at bottom-left
        let imageExtent = inputImage.extent
        let xPosition = imageExtent.width - textSize.width - 20
        let yPosition: CGFloat = 20  // 20 points from bottom
        
        // Transform to position the text
        let transform = CGAffineTransform(translationX: xPosition, y: yPosition)
        let transformedText = textCIImage.transformed(by: transform)
        
        // Composite the text over the image
        return transformedText.composited(over: inputImage)
    }
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                currentVideoInput = videoDeviceInput
                videoDevicePosition = videoDevice.position
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (videoDevicePosition == .front)
                }
            }
        } else {
            print("Couldn't add video output to the session.")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
            } else {
                print("Couldn't add photo output to the session.")
            }
        }
        
        session.commitConfiguration()
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        
        // Capture the photo
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        // Check current authorization status
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized {
                    self.performSave(image)
                } else {
                    print("Photo library access denied")
                }
            }
        case .authorized, .limited:
            self.performSave(image)
        default:
            print("Photo library access denied or restricted")
        }
    }
    
    private func performSave(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if success {
                print("Photo saved to library")
                DispatchQueue.main.async {
                    // Navigate to photo library after saving
                    self.capturePhotoCompletion?(image)
                }
            } else if let error = error {
                print("Error saving photo: \(error)")
            }
        }
    }
    
    private func generateLightLeak(for extent: CGRect) -> CIImage? {
        // Generate random position for light leak
        let positions = [
            CGPoint(x: 0, y: 0),                               // Top-left corner
            CGPoint(x: extent.width, y: 0),                    // Top-right corner
            CGPoint(x: 0, y: extent.height),                   // Bottom-left corner
            CGPoint(x: extent.width, y: extent.height),        // Bottom-right corner
            CGPoint(x: extent.width * 0.5, y: 0),              // Top center
            CGPoint(x: extent.width * 0.5, y: extent.height)   // Bottom center
        ]
        
        // Pick a random position
        let position = positions.randomElement() ?? positions[0]
        
        // Create radial gradient for light leak
        let radialGradient = CIFilter.radialGradient()
        radialGradient.center = position
        radialGradient.radius0 = 0
        radialGradient.radius1 = Float(max(extent.width, extent.height) * 0.7)
        
        // Create warm light leak colors
        let colors = [
            CIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0),  // Warm yellow
            CIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0),  // Orange
            CIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0),  // Peachy
            CIColor(red: 0.9, green: 0.4, blue: 0.3, alpha: 1.0),  // Red-orange
            CIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1.0)   // Pale yellow
        ]
        
        let color = colors.randomElement() ?? colors[0]
        radialGradient.color0 = color
        radialGradient.color1 = CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.0)
        
        guard let gradientImage = radialGradient.outputImage else { return nil }
        
        // Apply gaussian blur for softer edges
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = gradientImage
        blur.radius = 20
        
        return blur.outputImage?.cropped(to: extent)
    }
    
    private func applyLightLeak(to inputImage: CIImage, intensity: Float) -> CIImage {
        guard intensity > 0 else { 
            cachedLightLeakImage = nil
            return inputImage 
        }
        
        // Regenerate light leak every 5 seconds for variety
        let now = Date()
        if cachedLightLeakImage == nil || now.timeIntervalSince(lastLightLeakGeneration) > 5.0 {
            cachedLightLeakImage = generateLightLeak(for: inputImage.extent)
            lastLightLeakGeneration = now
        }
        
        guard let lightLeak = cachedLightLeakImage else { return inputImage }
        
        // Apply screen blend mode for natural light effect
        let screenBlend = CIFilter.screenBlendMode()
        screenBlend.inputImage = lightLeak
        screenBlend.backgroundImage = inputImage
        
        guard let blendedImage = screenBlend.outputImage else { return inputImage }
        
        // Mix based on intensity
        let mixer = CIFilter.dissolveTransition()
        mixer.inputImage = inputImage
        mixer.targetImage = blendedImage
        mixer.time = intensity * 0.6  // Scale down intensity for subtlety
        
        return mixer.outputImage ?? inputImage
    }
    
    private func createRadialMask(for extent: CGRect, centerPoint: CGPoint, radius: Float) -> CIImage? {
        // Create a radial gradient for the mask
        let gradientFilter = CIFilter.radialGradient()
        
        // Convert normalized point (0-1) to image coordinates
        let centerX = extent.origin.x + extent.width * CGFloat(centerPoint.x)
        let centerY = extent.origin.y + extent.height * (1.0 - CGFloat(centerPoint.y)) // Invert Y
        
        gradientFilter.center = CGPoint(x: centerX, y: centerY)
        gradientFilter.radius0 = Float(min(extent.width, extent.height) * 0.15) * radius  // Focus area
        gradientFilter.radius1 = Float(max(extent.width, extent.height) * 0.5) * radius   // Blur transition
        
        // White center (no blur), black edges (full blur)
        gradientFilter.color0 = CIColor.white
        gradientFilter.color1 = CIColor.black
        
        return gradientFilter.outputImage?.cropped(to: extent)
    }
    
    private func applySelectiveBokeh(to inputImage: CIImage, intensity: Float, focusPoint: CGPoint) -> CIImage {
        guard intensity > 0 else { return inputImage }
        
        // First create blurred version of entire image
        let blurredImage: CIImage
        if #available(iOS 11.0, *) {
            let bokehBlur = CIFilter.bokehBlur()
            bokehBlur.inputImage = inputImage
            bokehBlur.radius = intensity * 35
            bokehBlur.ringAmount = 0.7
            bokehBlur.ringSize = 0.2
            bokehBlur.softness = 1.0
            blurredImage = bokehBlur.outputImage?.cropped(to: inputImage.extent) ?? inputImage
        } else {
            let gaussianBlur = CIFilter.gaussianBlur()
            gaussianBlur.inputImage = inputImage
            gaussianBlur.radius = intensity * 25
            blurredImage = gaussianBlur.outputImage?.cropped(to: inputImage.extent) ?? inputImage
        }
        
        // Use person mask if available
        if let personMask = lastPersonMask {
            // Scale mask to match input image size
            let scaleX = inputImage.extent.width / personMask.extent.width
            let scaleY = inputImage.extent.height / personMask.extent.height
            let scaledMask = personMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            // Person mask: white = person, black = background
            // For CIBlendWithMask: white shows inputImage (sharp), black shows backgroundImage (blurred)
            // So we use the mask as-is (person = white = sharp)
            
            let blendFilter = CIFilter.blendWithMask()
            blendFilter.inputImage = inputImage  // Sharp original
            blendFilter.backgroundImage = blurredImage  // Blurred background
            blendFilter.maskImage = scaledMask  // Person mask
            
            return blendFilter.outputImage?.cropped(to: inputImage.extent) ?? inputImage
        } else {
            // Fallback: use radial gradient for focus point
            if let radialMask = createRadialMask(for: inputImage.extent, centerPoint: focusPoint, radius: 1.5) {
                
                // Invert the radial mask (center should be white/sharp)
                let invertFilter = CIFilter.colorInvert()
                invertFilter.inputImage = radialMask
                let invertedMask = invertFilter.outputImage ?? radialMask
                
                let blendFilter = CIFilter.blendWithMask()
                blendFilter.inputImage = inputImage  // Sharp original
                blendFilter.backgroundImage = blurredImage  // Blurred background
                blendFilter.maskImage = invertedMask  // Inverted radial mask
                
                return blendFilter.outputImage?.cropped(to: inputImage.extent) ?? inputImage
            }
        }
        
        return inputImage
    }
    
    private func applyBokehBlur(to inputImage: CIImage, intensity: Float) -> CIImage {
        guard intensity > 0 else { return inputImage }
        
        // Check if selective bokeh is enabled
        if isSelectiveBokeh {
            return applySelectiveBokeh(to: inputImage, intensity: intensity, focusPoint: lastFocusPoint)
        }
        
        // Full frame bokeh blur
        if #available(iOS 11.0, *) {
            let bokehBlur = CIFilter.bokehBlur()
            bokehBlur.inputImage = inputImage
            bokehBlur.radius = intensity * 30  // Radius 0-30
            bokehBlur.ringAmount = 0.5  // Ring emphasis
            bokehBlur.ringSize = 0.1   // Ring size
            bokehBlur.softness = 0.7    // Edge softness
            
            if let outputImage = bokehBlur.outputImage {
                // Ensure the output maintains the original extent
                return outputImage.cropped(to: inputImage.extent)
            }
        }
        
        // Fallback to Gaussian blur for older iOS versions
        let gaussianBlur = CIFilter.gaussianBlur()
        gaussianBlur.inputImage = inputImage
        gaussianBlur.radius = intensity * 15
        
        if let outputImage = gaussianBlur.outputImage {
            return outputImage.cropped(to: inputImage.extent)
        }
        
        return inputImage
    }
    
    private func applyGrain(to inputImage: CIImage, intensity: Float) -> CIImage {
        guard intensity > 0 else { return inputImage }
        
        // Generate random noise
        let randomGenerator = CIFilter.randomGenerator()
        guard let noiseImage = randomGenerator.outputImage else { return inputImage }
        
        // Scale noise to match image size
        let noiseScaled = noiseImage
            .transformed(by: CGAffineTransform(scaleX: 1.5, y: 1.5))
            .cropped(to: inputImage.extent)
        
        // Convert noise to grayscale and adjust contrast
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = noiseScaled
        colorControls.saturation = 0
        colorControls.brightness = -0.5
        colorControls.contrast = 1.5
        
        guard let processedNoise = colorControls.outputImage else { return inputImage }
        
        // Apply soft blur to make grain more natural
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = processedNoise
        blur.radius = 0.5
        
        guard let blurredNoise = blur.outputImage else { return inputImage }
        
        // Blend noise with original image
        let blend = CIFilter.screenBlendMode()
        blend.inputImage = blurredNoise
        blend.backgroundImage = inputImage
        
        guard let blendedImage = blend.outputImage else { return inputImage }
        
        // Mix based on intensity
        let mixer = CIFilter.dissolveTransition()
        mixer.inputImage = inputImage
        mixer.targetImage = blendedImage
        mixer.time = intensity
        
        return mixer.outputImage ?? inputImage
    }
    
    private func applyFilter(to inputImage: CIImage) -> CIImage {
        switch selectedFilter {
        case .none:
            return inputImage
            
        case .portra400:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.05
            colorControls.contrast = 1.05
            colorControls.saturation = 0.9
            
            let sepiaTone = CIFilter.sepiaTone()
            sepiaTone.inputImage = colorControls.outputImage
            sepiaTone.intensity = 0.1
            
            let vignette = CIFilter.vignette()
            vignette.inputImage = sepiaTone.outputImage
            vignette.intensity = 0.3
            vignette.radius = 1.5
            
            return vignette.outputImage ?? inputImage
            
        case .velvia50:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.05
            colorControls.contrast = 1.3
            colorControls.saturation = 1.5
            
            let vignette = CIFilter.vignette()
            vignette.inputImage = colorControls.outputImage
            vignette.intensity = 0.4
            vignette.radius = 1.3
            
            return vignette.outputImage ?? inputImage
            
        case .tri400:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.02
            colorControls.contrast = 1.2
            colorControls.saturation = 0
            
            let noiseReduction = CIFilter.noiseReduction()
            noiseReduction.inputImage = colorControls.outputImage
            noiseReduction.noiseLevel = 0.02
            noiseReduction.sharpness = 1.0
            
            let vignette = CIFilter.vignette()
            vignette.inputImage = noiseReduction.outputImage
            vignette.intensity = 0.5
            vignette.radius = 1.2
            
            return vignette.outputImage ?? inputImage
            
        case .gold200:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.08
            colorControls.contrast = 1.1
            colorControls.saturation = 1.2
            
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 7000, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 5500, y: 5)
            
            return temperatureAndTint.outputImage ?? inputImage
            
        case .cinestill800T:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.02
            colorControls.contrast = 1.15
            colorControls.saturation = 1.1
            
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 5000, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 3200, y: 10)
            
            // Use a gentler bloom effect to avoid extent changes
            let bloom = CIFilter.bloom()
            bloom.inputImage = temperatureAndTint.outputImage
            bloom.intensity = 0.3
            bloom.radius = 8
            
            // Add a slight vignette for cinematic look
            let vignette = CIFilter.vignette()
            vignette.inputImage = bloom.outputImage
            vignette.intensity = 0.35
            vignette.radius = 1.4
            
            return vignette.outputImage ?? inputImage
            
        case .ektachrome:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.0
            colorControls.contrast = 1.25
            colorControls.saturation = 1.3
            
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = colorControls.outputImage
            vibrance.amount = 0.5
            
            return vibrance.outputImage ?? inputImage
            
        case .fujiSuperia:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.06
            colorControls.contrast = 1.08
            colorControls.saturation = 1.15
            
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 5800, y: 3)
            
            return temperatureAndTint.outputImage ?? inputImage
            
        case .kodakVision:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.03
            colorControls.contrast = 1.18
            colorControls.saturation = 0.95
            
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 5600, y: -5)
            
            let vignette = CIFilter.vignette()
            vignette.inputImage = temperatureAndTint.outputImage
            vignette.intensity = 0.25
            vignette.radius = 1.8
            
            return vignette.outputImage ?? inputImage
            
        case .ilfordHP5:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = -0.02
            colorControls.contrast = 1.3
            colorControls.saturation = 0
            
            let sharpenLuminance = CIFilter.sharpenLuminance()
            sharpenLuminance.inputImage = colorControls.outputImage
            sharpenLuminance.sharpness = 0.4
            
            let vignette = CIFilter.vignette()
            vignette.inputImage = sharpenLuminance.outputImage
            vignette.intensity = 0.6
            vignette.radius = 1.0
            
            return vignette.outputImage ?? inputImage
            
        case .agfaVista:
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = inputImage
            colorControls.brightness = 0.1
            colorControls.contrast = 1.12
            colorControls.saturation = 1.25
            
            let temperatureAndTint = CIFilter.temperatureAndTint()
            temperatureAndTint.inputImage = colorControls.outputImage
            temperatureAndTint.neutral = CIVector(x: 6500, y: 0)
            temperatureAndTint.targetNeutral = CIVector(x: 6000, y: 8)
            
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = temperatureAndTint.outputImage
            vibrance.amount = 0.3
            
            return vibrance.outputImage ?? inputImage
        }
    }
}

extension FilteredCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        // Use the last processed image with filters applied
        if let processedImage = lastProcessedImage,
           let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            
            // Save to photo library
            saveImageToPhotoLibrary(uiImage)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            // Fallback: save original photo if no processed image
            saveImageToPhotoLibrary(image)
        }
    }
}

extension FilteredCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Generate person mask for selective bokeh (iOS 15+)
        if #available(iOS 15.0, *), isSelectiveBokeh && bokehIntensity > 0 {
            generatePersonMask(from: pixelBuffer) { [weak self] mask in
                if let mask = mask {
                    self?.lastPersonMask = mask
                }
            }
        }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply proper orientation transform
        let deviceOrientation = UIDevice.current.orientation
        let imageOrientation: CGImagePropertyOrientation
        
        if videoDevicePosition == .front {
            // Front camera - needs mirroring
            imageOrientation = .upMirrored
        } else {
            // Back camera - no mirroring
            imageOrientation = .up
        }
        
        ciImage = ciImage.oriented(imageOrientation)
        
        // Store original extent before applying filters
        let originalExtent = ciImage.extent
        
        // Apply filter
        let filteredImage = applyFilter(to: ciImage)
        
        // Apply bokeh blur effect
        let bokehImage = applyBokehBlur(to: filteredImage, intensity: bokehIntensity)
        
        // Apply light leak effect
        let lightLeakedImage = applyLightLeak(to: bokehImage, intensity: lightLeakIntensity)
        
        // Apply grain effect after light leak
        let grainedImage = applyGrain(to: lightLeakedImage, intensity: grainIntensity)
        
        // Apply date stamp if enabled
        let stampedImage = showDateStamp ? applyDateStamp(to: grainedImage) : grainedImage
        
        // Ensure the filtered image maintains the original extent
        // This prevents filters like bloom from changing the preview size
        let finalImage: CIImage
        if stampedImage.extent != originalExtent {
            // Crop back to original size if the filter changed the extent
            finalImage = stampedImage.cropped(to: originalExtent)
        } else {
            finalImage = stampedImage
        }
        
        // Store the processed image for photo capture
        lastProcessedImage = finalImage
        
        if let cgImage = ciContext.createCGImage(finalImage, from: originalExtent) {
            DispatchQueue.main.async {
                self.filterView.image = UIImage(cgImage: cgImage)
            }
        }
    }
}