import UIKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet var arView: ARView!
    
    // UI elements for recording
    var recordButton: UIButton!
    var stopButton: UIButton!
    var saveButton: UIButton!
    var fileNameTextField: UITextField!
    
    // Body Tracking Data
    var isRecording = false
    var recordedFrames: [[String: (simd_float3, simd_quatf, TimeInterval)]] = [] // Store joint data with position, rotation, and timestamp
    
    // The 3D character to display
    var character: BodyTrackedEntity?
    let characterAnchor = AnchorEntity()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        arView.scene.addAnchor(characterAnchor)
        
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "character/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
        }, receiveValue: { (character: Entity) in
            if let character = character as? BodyTrackedEntity {
                character.scale = [1.0, 1.0, 1.0]
                self.character = character
                cancellable?.cancel()
            } else {
                print("Error: Unable to load model as BodyTrackedEntity")
            }
        })
    }
    
    func setupUI() {
        // Record Button
        recordButton = UIButton(type: .system)
        recordButton.setTitle("Record", for: .normal)
        recordButton.setTitleColor(.red, for: .normal)
        recordButton.frame = CGRect(x: 20, y: 50, width: 100, height: 50)
        recordButton.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
        view.addSubview(recordButton)
        
        // Stop Button
        stopButton = UIButton(type: .system)
        stopButton.setTitle("Stop", for: .normal)
        stopButton.setTitleColor(.red, for: .normal)
        stopButton.frame = CGRect(x: 140, y: 50, width: 100, height: 50)
        stopButton.addTarget(self, action: #selector(stopRecording), for: .touchUpInside)
        stopButton.isHidden = true // Initially hide the stop button
        view.addSubview(stopButton)
        
        // Save Button
        saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(.red, for: .normal)
        saveButton.frame = CGRect(x: 260, y: 50, width: 100, height: 50)
        saveButton.addTarget(self, action: #selector(saveRecordingWithFileName), for: .touchUpInside)
        saveButton.isHidden = true
        view.addSubview(saveButton)
        
        // File Name Text Field
        fileNameTextField = UITextField(frame: CGRect(x: 20, y: 110, width: 240, height: 40))
        fileNameTextField.borderStyle = .roundedRect
        fileNameTextField.placeholder = "Enter file name"
        fileNameTextField.isHidden = true
        view.addSubview(fileNameTextField)
    }
    
    @objc func startRecording() {
        isRecording = true
        recordedFrames = [] // Clear previous recordings
        print("Recording started")
        
        // Show the Stop button and hide the Record button
        recordButton.isHidden = true
        stopButton.isHidden = false
    }
    
    @objc func stopRecording() {
        isRecording = false
        print("Recording stopped")
        
        // Show the Save button and text field
        stopButton.isHidden = true
        fileNameTextField.isHidden = false
        saveButton.isHidden = false
    }
    
    @objc func saveRecordingWithFileName() {
        guard let fileName = fileNameTextField.text, !fileName.isEmpty else {
            print("Error: File name is empty")
            return
        }
        
        saveRecording(fileName: fileName)
        
        // Hide the Save button and text field, show the Record button
        fileNameTextField.isHidden = true
        saveButton.isHidden = true
        recordButton.isHidden = false
    }
    
    func saveRecording(fileName: String) {
        // Get the Documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Unable to access the Documents directory.")
            return
        }
        
        // Create the BodyTrackingData folder
        let folderURL = documentsURL.appendingPathComponent("BodyTrackingData")
        do {
            if !fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                print("Created folder at: \(folderURL.path)")
            }
        } catch {
            print("Error creating folder: \(error.localizedDescription)")
            return
        }
        
        // Create the CSV file path
        let fileURL = folderURL.appendingPathComponent("\(fileName).csv")
        
        // Generate the CSV data
        var csvString = "Frame,JointName,Timestamp,PositionX,PositionY,PositionZ,RotationX,RotationY,RotationZ,RotationW\n" // CSV Header
        for (frameIndex, frameData) in recordedFrames.enumerated() {
            for (jointName, (position, rotation, timestamp)) in frameData {
                csvString += "\(frameIndex),\(jointName),\(timestamp),\(position.x),\(position.y),\(position.z),\(rotation.vector.x),\(rotation.vector.y),\(rotation.vector.z),\(rotation.vector.w)\n"
            }
        }
        
        // Write the CSV data to the file
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Data saved successfully to: \(fileURL.path)")
        } catch {
            print("Error saving CSV file: \(error.localizedDescription)")
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.position = bodyPosition
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
            
            if let character = character, character.parent == nil {
                characterAnchor.addChild(character)
            }
            
            if isRecording {
                // Record joint data along with timestamp and rotation
                let timestamp = Date().timeIntervalSince1970 // Current time in seconds
                var frameData: [String: (simd_float3, simd_quatf, TimeInterval)] = [:]
                
                for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
                    if let jointTransform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: jointName)) {
                        let position = simd_make_float3(jointTransform.columns.3)
                        let rotation = simd_quatf(jointTransform)
                        frameData[jointName] = (position, rotation, timestamp)
                    }
                }
                recordedFrames.append(frameData)
            }
        }
    }
}
