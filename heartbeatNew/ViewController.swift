//
//  ViewController.swift
//  heartbeatNew
//
//  Created by Varun Narayanswamy on 6/11/22.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var preview: UIView!
    @IBOutlet weak var heartBeatLabel: UILabel!
    @IBOutlet weak var heartbeatButton: UIButton!
    var imageView: UIImage!
    var startDate: Date?
    var endDate: Date?
    var startRecording = false
    var frontCamera: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var data_arr = [UInt32]()
    var cameraSession = AVCaptureSession()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermissions()
        heartBeatLabel.layer.zPosition = 1
        preview.backgroundColor = UIColor.black
        cameraSession.sessionPreset = AVCaptureSession.Preset.high

        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
        do {
            let videoInput = try AVCaptureDeviceInput(device: frontCamera!)
            if cameraSession.canAddInput(videoInput) {
                cameraSession.addInput(videoInput)
            }
        }
        catch {
            print("unable to add front camera")
            return
        }
        let previewLayer = AVCaptureVideoPreviewLayer.init(session: cameraSession)
        
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = preview.bounds
        if (previewLayer.connection?.isVideoOrientationSupported)! {
            previewLayer.connection?.videoOrientation = .portrait
        } else {
            print("unable to setup portrait orientation")
        }
            
        preview.layer.addSublayer(previewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
                
        let videoOutputQueue = DispatchQueue(label: "videoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
         if cameraSession.canAddOutput(videoOutput) {
             cameraSession.addOutput(videoOutput)
        } else {
            print("Could not add video data as output.")
        }
        cameraSession.startRunning()
        self.toggleFlash(on: true)
    }
    
    @IBAction func toggleVid(_ sender: Any) {
        if (startRecording) {
            startRecording = false
            self.endDate = Date()
            cameraSession.stopRunning()
            preview.backgroundColor = .black
            self.toggleFlash(on: false)
            
            self.findHeartbeat()
        } else {
            self.heartbeatButton.setTitle("Finish data retrieval", for: .normal)
            self.heartBeatLabel.text = "Will begin retrieving heartbeat data after 5 seconds. Please keep hand steady"
            self.data_arr.removeAll()
            cameraSession.startRunning()
            self.toggleFlash(on: true)
            startRecording = true
            self.startDate = Date()
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [self] granted in
                if (!granted) {
                    print("permissions not given")
                }
            }
        case .denied, .restricted:
            print("permission denied")
        default:
            return
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                
            CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                    
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bitsPerComponent = 8
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
                    
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)!
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
            if let context = newContext {
                let cameraFrame = context.makeImage()
                DispatchQueue.main.async {
                    self.imageView = UIImage(cgImage: cameraFrame!)
                    if (self.startRecording) {
                        self.checkImagePixelData()
                    }
                }
            }
                    
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        } else {
            print("Unable to find image buffer object")
        }

    }
    
//    func manualFilter() {
//        let cgImg = self.imageView.cgImage!
//        let pixelData = cgImg.dataProvider!.data
//        let bytes: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
//        let byte_array = bytes
//        var g = UInt32(0)
//
//
//        assert(cgImg.colorSpace?.model == .rgb)
//
//        let bytesPerPixel = cgImg.bitsPerPixel / cgImg.bitsPerComponent
//        let bytes_per_row = cgImg.bytesPerRow
//        let y_min = Int(cgImg.height/3)
//        let y_max = 2*y_min
//        let x_min = Int(cgImg.width/3)
//        let x_max = 2*x_min
//
//        for x in x_min ..< x_max {
//            for y in y_min ..< y_max {
//                g += UInt32(byte_array[(y * bytes_per_row) + (x * bytesPerPixel)+1])
//            }
//        }
//        self.fiveSecondDelay(colorVal: g)
//    }
//
    func checkImagePixelData() {
        if let image = CIImage(image: self.imageView) {
            var bitmap = [UInt8](repeating: 0, count: 4)
            var extentVector: CIVector?
            var filter: CIFilter?
            var outputImage: CIImage?
            var context = CIContext(options: [.workingColorSpace: kCFNull])
                    
            extentVector = CIVector(x: image.extent.origin.x, y: image.extent.origin.y, z: image.extent.size.width, w: image.extent.size.height)
            
            filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image, kCIInputExtentKey: extentVector])
            
            outputImage = filter?.outputImage
            context = CIContext(options: [.workingColorSpace: kCFNull])
            context.render(outputImage!, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            if (startRecording) {
                self.fiveSecondDelay(colorVal: UInt32(bitmap[0]))
            }

        }
    }
    
    private func fiveSecondDelay(colorVal: UInt32) {
        let currentTime = Date()
        let timeSinceStarted = currentTime.timeIntervalSinceReferenceDate - self.startDate!.timeIntervalSinceReferenceDate
        if (timeSinceStarted > 5) {
            self.heartbeatButton.isEnabled = true
            self.heartBeatLabel.text = "Retrieving HeartBeat"
            data_arr.append(colorVal)
        } else {
            self.heartbeatButton.isEnabled = false
            print("please wait for a little bit and make sure the phone is stable")
        }
    }
    
    private func toggleFlash(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard device.hasTorch else {
            print("unable to find flash")
            return
        }
        do {
            try device.lockForConfiguration()
            if (on) {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        }
        catch {
            print("unable to set flash")
        }
    }

    func findHeartbeat() {
        print("finding heart beat")
        var peaks = 0
        var ascending = false
        for i in 1 ..< data_arr.count-1 {
            if data_arr[i] > data_arr[i-1]  {
                ascending = true
            }
            if (ascending && data_arr[i] > data_arr[i+1]) {
                print(data_arr[i])
                ascending = false
                peaks += 1
            }
        }
        let delta = endDate!.timeIntervalSinceReferenceDate - startDate!.timeIntervalSinceReferenceDate - 5
        let scalor = 60/delta
        let heart_beat = Double(peaks) * scalor
        self.heartBeatLabel.text = String(Int(heart_beat)) + " BPM"
        self.heartbeatButton.setTitle("Check HeartRate", for: .normal)
    }

}
