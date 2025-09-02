import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct FilteredCameraView: UIViewControllerRepresentable {
    @Binding var selectedFilter: FilmFilter
    @Binding var grainIntensity: Double
    
    func makeUIViewController(context: Context) -> FilteredCameraViewController {
        let controller = FilteredCameraViewController()
        controller.selectedFilter = selectedFilter
        controller.grainIntensity = Float(grainIntensity)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: FilteredCameraViewController, context: Context) {
        uiViewController.selectedFilter = selectedFilter
        uiViewController.grainIntensity = Float(grainIntensity)
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
        view.addSubview(filterView)
        
        ciContext = CIContext(options: [.useSoftwareRenderer: false])
        
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
        
        session.commitConfiguration()
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

extension FilteredCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
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
        
        // Apply grain effect after filter
        let grainedImage = applyGrain(to: filteredImage, intensity: grainIntensity)
        
        // Ensure the filtered image maintains the original extent
        // This prevents filters like bloom from changing the preview size
        let finalImage: CIImage
        if grainedImage.extent != originalExtent {
            // Crop back to original size if the filter changed the extent
            finalImage = grainedImage.cropped(to: originalExtent)
        } else {
            finalImage = grainedImage
        }
        
        if let cgImage = ciContext.createCGImage(finalImage, from: originalExtent) {
            DispatchQueue.main.async {
                self.filterView.image = UIImage(cgImage: cgImage)
            }
        }
    }
}