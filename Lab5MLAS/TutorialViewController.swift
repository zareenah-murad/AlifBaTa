//
//  TutorialViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/25/24.
//  Updated on 11/27/24.
//

import UIKit
import AVFoundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class TutorialViewController: UIViewController {

    // MARK: - Properties
    var touchCoordinates = [(x: Double, y: Double)]()
    var drawnPath = UIBezierPath() // Path for user's drawing
    var drawnLayer = CAShapeLayer() // Layer for the user's drawing
    var tutorialData: [(features: [Double], label: String)] = [] // Collected tutorial data
    var isAnimatingText = false
    var audioPlayer: AVAudioPlayer? // Audio player for letter sounds
    
    let letterSounds: [String: String] = [
        "ا": "Alif.wav",
        "ب": "Ba.wav",
        "ت": "Ta.wav",
        "ث": "Sa.wav",
        "ج": "Jeem.wav",
        "ح": "Hha.wav",
        "خ": "Kha.wav",
        "د": "Dal.wav",
        "ذ": "Taj Zhal.wav",
        "ر": "Raa.wav",
        "ز": "Taj Zaa.wav",
        "س": "Seen.wav",
        "ش": "Sheen.wav",
        "ص": "Saud.wav",
        "ض": "Duad.wav",
        "ط": "Taj Tua.wav",
        "ظ": "Taj Zua.wav",
        "ع": "Aain.wav",
        "غ": "Ghain.wav",
        "ف": "Faa.wav",
        "ق": "Qauf.wav",
        "ك": "Kaif.wav",
        "ل": "Laam.wav",
        "م": "Meem.wav",
        "ن": "Noon.wav",
        "ه": "Haa.wav",
        "و": "Taj wao.wav",
        "ي": "Taj Yaa.wav"
    ]

    
    var dashSegments: [(path: UIBezierPath, layer: CAShapeLayer)] = [] // Individual dash segments
    var boundingBoxLayer = CAShapeLayer()
    
    // MARK: - Levels and Progress
    let levels: [[String]] = [
        ["ا", "ب", "ت", "ث", "ج", "ح", "خ"], // Lesson 1
        ["د", "ذ", "ر", "ز", "س", "ش", "ص"], // Lesson 2
        ["ض", "ط", "ظ", "ع", "غ", "ف", "ق"], // Lesson 3
        ["ك", "ل", "م", "ن", "ه", "و", "ي"]  // Lesson 4
    ]
    
    var currentLessonIndex = 0    // Current lesson number (0-based)
    var currentLetterIndex = 0    // Current letter index within a lesson
    var currentLetters: [String] { return levels[currentLessonIndex] } // Letters in the current lesson
    var onLessonComplete: (() -> Void)? // Closure to notify lesson completion

    
    private let instructionsLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private let submitButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let playSoundButton = UIButton(type: .system) // Button to play the sound
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    let buttonWidthMultiplier: CGFloat = 0.6 // 60% of the bounding box width
    private var animationTimer: Timer? // Timer to handle the animation



    let client = MlaasModel()

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black

        setupUI()
        setupConstraints()
        setupDrawingLayer()
        setupBoundingBox()
        
        progressView.progress = 0.0
        progressLabel.isHidden = true
        submitButton.isEnabled = false
        clearButton.isEnabled = false

        loadNextLetter()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Activity Indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        view.bringSubviewToFront(activityIndicator)
        
        // Instructions Label
        instructionsLabel.text = "Instructions Label"
        instructionsLabel.font = UIFont.boldSystemFont(ofSize: 22)
        instructionsLabel.textColor = .white
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        view.addSubview(instructionsLabel)

        // Progress View
        progressView.tintColor = .systemBlue
        view.addSubview(progressView)

        // Progress Label
        progressLabel.text = "Progress Label"
        progressLabel.font = UIFont.systemFont(ofSize: 16)
        progressLabel.textColor = .white
        progressLabel.textAlignment = .center
        progressLabel.numberOfLines = 0
        view.addSubview(progressLabel)
        
        setupButtons()
    }
    
    func setupButtons() {
        // Configure Play Sound Button
        configureButton(
            button: playSoundButton,
            title: "Play Sound",
            backgroundColor: UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0),
            titleColor: .black,
            action: #selector(playSoundButtonTapped(_:))
        )
        view.addSubview(playSoundButton)

        // Configure Clear Button
        configureButton(
            button: clearButton,
            title: "Clear",
            backgroundColor: UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0),
            titleColor: .white,
            action: #selector(clearButtonTapped(_:))
        )
        view.addSubview(clearButton)

        // Configure Submit Button
        configureButton(
            button: submitButton,
            title: "Submit",
            backgroundColor: UIColor(red: 0.0, green: 0.1, blue: 0.4, alpha: 1.0),
            titleColor: .white,
            action: #selector(submitButtonTapped(_:))
        )
        view.addSubview(submitButton)

        // Add Constraints
        applyButtonConstraints()
    }

    private func configureButton(button: UIButton, title: String, backgroundColor: UIColor, titleColor: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
    }
    
    private func applyButtonConstraints() {
        let boundingBoxWidth: CGFloat = 300 * buttonWidthMultiplier

        NSLayoutConstraint.activate([
            // Play Sound Button
            playSoundButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playSoundButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            playSoundButton.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -16),
            playSoundButton.heightAnchor.constraint(equalToConstant: 50),

            // Clear Button
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            clearButton.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -16),
            clearButton.heightAnchor.constraint(equalToConstant: 50),

            // Submit Button
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            submitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }



    // MARK: - Constraints
    private func setupConstraints() {
        // Disable autoresizing masks for all UI components
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        playSoundButton.translatesAutoresizingMaskIntoConstraints = false

        // Add Description Label
        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = "Trace each letter carefully, listen to its sound, and prepare to be quizzed later to unlock the next level!"
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        view.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            // Progress View
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            progressView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            progressView.heightAnchor.constraint(equalToConstant: 10),

            // Instructions Label
            instructionsLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            instructionsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Description Label
            descriptionLabel.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Progress Label
            progressLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Activity Indicator
            activityIndicator.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 8), // Close to progressLabel
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),

        ])
        view.bringSubviewToFront(activityIndicator)
    }


    // MARK: - Play Sound
    @objc private func playSoundButtonTapped(_ sender: UIButton) {
        guard let currentLetter = currentLetters[safe: currentLetterIndex],
              let soundFile = letterSounds[currentLetter],
              let soundURL = Bundle.main.url(forResource: soundFile, withExtension: nil) else {
            print("Sound file not found for letter: \(currentLetters[currentLetterIndex])")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }


    func setupDrawingLayer() {
        drawnLayer.strokeColor = UIColor.white.cgColor
        drawnLayer.lineWidth = 19.0
        drawnLayer.fillColor = UIColor.clear.cgColor

        // Ensure drawnLayer is only added once and stays in place
        if !view.layer.sublayers!.contains(drawnLayer) {
            view.layer.addSublayer(drawnLayer)
        }
        
        // Bring the drawnLayer to the front
        view.layer.insertSublayer(drawnLayer, at: UInt32(view.layer.sublayers?.count ?? 0))
        
    }

    func setupBoundingBox() {
        let boxWidth: CGFloat = 300 // Adjust width
        let boxHeight: CGFloat = 300 // Adjust height
        let centerX = view.bounds.midX
        let centerY = view.bounds.midY

        // Create the bounding box
        let boundingBox = CGRect(x: centerX - boxWidth / 2, y: centerY - boxHeight / 2, width: boxWidth, height: boxHeight)
        boundingBoxLayer.path = UIBezierPath(rect: boundingBox).cgPath
        boundingBoxLayer.strokeColor = UIColor.blue.cgColor
        boundingBoxLayer.lineWidth = 2.0
        boundingBoxLayer.fillColor = UIColor.clear.cgColor

        // Add the bounding box back to the view after clearing other layers
        if view.layer.sublayers?.contains(boundingBoxLayer) == false {
            view.layer.addSublayer(boundingBoxLayer)
        }
    }

    func createLetterPath(for letter: String) {
        // Clear previous dashed lines
        for segment in dashSegments {
            segment.layer.removeFromSuperlayer()
        }
        dashSegments.removeAll()

        switch letter {
        // Lesson 1 Letters
        case "ا":
            let centerX = view.bounds.midX
            let centerY = view.bounds.midY
            let verticalOffset: CGFloat = -20
            createDashedLine(
                from: CGPoint(x: centerX, y: centerY + verticalOffset - 100),
                to: CGPoint(x: centerX, y: centerY + verticalOffset + 100)
            )
        case "ب":
            createDashedCurve(from: CGPoint(x: 100, y: 360), to: CGPoint(x: 300, y: 360),
                                controlPoint1: CGPoint(x: 50, y: 456), controlPoint2: CGPoint(x: 350, y: 456))
            createDot(at: CGPoint(x: 200, y: 480))
        case "ت":
            createDashedCurve(from: CGPoint(x: 100, y: 380), to: CGPoint(x: 300, y: 380),
                                  controlPoint1: CGPoint(x: 50, y: 476), controlPoint2: CGPoint(x: 350, y: 476))
            createDot(at: CGPoint(x: 180, y: 350))
            createDot(at: CGPoint(x: 220, y: 350))
        case "ث":
            createDashedCurve(from: CGPoint(x: 100, y: 380), to: CGPoint(x: 300, y: 380),
                                  controlPoint1: CGPoint(x: 50, y: 476), controlPoint2: CGPoint(x: 350, y: 476))
            createDot(at: CGPoint(x: 180, y: 355))
            createDot(at: CGPoint(x: 220, y: 355))
            createDot(at: CGPoint(x: 200, y: 335))
        case "ج":
            createDashedCurve(
                from: CGPoint(x: 139, y: 348),
                to: CGPoint(x: 254, y: 341),
                controlPoint1: CGPoint(x: 193, y: 289),
                controlPoint2: CGPoint(x: 192, y: 378)
            )
            createDashedCurve(
                from: CGPoint(x: 254, y: 341),
                to: CGPoint(x: 254, y: 471),
                controlPoint1: CGPoint(x: 117, y: 365),
                controlPoint2: CGPoint(x: 117, y: 527)
            )
            createDot(at: CGPoint(x: 208, y: 428))
        case "ح":
            createDashedCurve(
                from: CGPoint(x: 139, y: 348),
                to: CGPoint(x: 254, y: 341),
                controlPoint1: CGPoint(x: 193, y: 289),
                controlPoint2: CGPoint(x: 192, y: 378)
            )
            createDashedCurve(
                from: CGPoint(x: 254, y: 341),
                to: CGPoint(x: 254, y: 471),
                controlPoint1: CGPoint(x: 117, y: 365),
                controlPoint2: CGPoint(x: 117, y: 527)
            )
        case "خ":
            createDashedCurve(
                from: CGPoint(x: 139, y: 348),
                to: CGPoint(x: 254, y: 341),
                controlPoint1: CGPoint(x: 193, y: 289),
                controlPoint2: CGPoint(x: 192, y: 378)
            )
            createDashedCurve(
                from: CGPoint(x: 254, y: 341),
                to: CGPoint(x: 254, y: 471),
                controlPoint1: CGPoint(x: 117, y: 365),
                controlPoint2: CGPoint(x: 117, y: 527)
            )
            createDot(at: CGPoint(x: 200, y: 300))
        case "س":
            createDashedCurve(from: CGPoint(x: 125.8, y: 415.9),
                to: CGPoint(x: 190.6, y: 415.9),
                controlPoint1: CGPoint(x: 44.8, y: 545.5),
                controlPoint2: CGPoint(x: 271.6, y: 545.5))
                    
            createDashedCurve(from: CGPoint(x: 198.9, y: 427.95),
                to: CGPoint(x: 254.1, y: 417.95),
                controlPoint1: CGPoint(x: 198.4, y: 482.75),
                controlPoint2: CGPoint(x: 270.8, y: 482.75))
                    
             createDashedCurve(from: CGPoint(x: 254.1, y: 417.95),
                to: CGPoint(x: 295.3, y: 417.95),
                controlPoint1: CGPoint(x: 237.4, y: 482.75),
                controlPoint2: CGPoint(x: 335.8, y: 482.75))

        case "ش":
            createDashedCurve(from: CGPoint(x: 125.8, y: 415.9),
                to: CGPoint(x: 190.6, y: 415.9),
                controlPoint1: CGPoint(x: 44.8, y: 545.5),
                controlPoint2: CGPoint(x: 271.6, y: 545.5))
                    
            createDashedCurve(from: CGPoint(x: 198.9, y: 427.95),
                to: CGPoint(x: 254.1, y: 417.95),
                controlPoint1: CGPoint(x: 198.4, y: 482.75),
                controlPoint2: CGPoint(x: 270.8, y: 482.75))
                    
            createDashedCurve(from: CGPoint(x: 254.1, y: 417.95),
                to: CGPoint(x: 295.3, y: 417.95),
                controlPoint1: CGPoint(x: 237.4, y: 482.75),
                controlPoint2: CGPoint(x: 335.8, y: 482.75))

                    
            createDot(at: CGPoint(x: 275, y: 400))
            createDot(at: CGPoint(x: 220, y: 400))
            createDot(at: CGPoint(x: 247.5, y: 370))
                
        case "ز":
            createDashedCurve(from: CGPoint(x: 150, y: 500),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 150, y: 510),
                controlPoint2: CGPoint(x: 300, y: 535))
            
            createDot(at: CGPoint(x: 235, y: 360))
            
        case "ر":
            createDashedCurve(from: CGPoint(x: 150, y: 500),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 150, y: 510),
                controlPoint2: CGPoint(x: 300, y: 535))
            
        case "ذ":
            createDashedCurve(from: CGPoint(x: 130, y: 490),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 120, y: 550),
                controlPoint2: CGPoint(x: 360, y: 535))
            
            createDot(at: CGPoint(x: 240, y: 360))
            
        case "د":
            createDashedCurve(from: CGPoint(x: 130, y: 490),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 120, y: 550),
                controlPoint2: CGPoint(x: 360, y: 535))
            
        case "ف":
            createDashedCurve(from: CGPoint(x: 240, y: 400),
                              to: CGPoint(x: 300, y: 460),
                              controlPoint1: CGPoint(x: 170, y: 400),
                              controlPoint2: CGPoint(x: 170, y: 550))
                            
            createDashedCurve(from: CGPoint(x: 150, y: 540),
                              to: CGPoint(x: 240, y: 400),
                              controlPoint1: CGPoint(x: 360, y: 600),
                              controlPoint2: CGPoint(x: 310, y: 395))
                            
            createDashedCurve(from: CGPoint(x: 150, y: 540),
                              to: CGPoint(x: 140, y: 460),
                              controlPoint1: CGPoint(x: 110, y: 520),
                              controlPoint2: CGPoint(x: 140, y: 460))

            createDot(at: CGPoint(x: 240, y: 370))
                    
        case "ق":
            createDashedCurve(from: CGPoint(x: 240, y: 380),
                              to: CGPoint(x: 300, y: 440),
                              controlPoint1: CGPoint(x: 170, y: 380),
                              controlPoint2: CGPoint(x: 170, y: 530))
                            
            createDashedCurve(from: CGPoint(x: 145, y: 520),
                              to: CGPoint(x: 240, y: 380),
                              controlPoint1: CGPoint(x: 370, y: 580),
                              controlPoint2: CGPoint(x: 310, y: 375))
                            
            createDashedCurve(from: CGPoint(x: 145, y: 520),
                              to: CGPoint(x: 140, y: 440),
                              controlPoint1: CGPoint(x: 105, y: 500),
                              controlPoint2: CGPoint(x: 140, y: 440))

            createDot(at: CGPoint(x: 220, y: 350))
            createDot(at: CGPoint(x: 260, y: 350))

            
        case "ك":
            createDashedCurve(from: CGPoint(x: 150, y: 450),
                to: CGPoint(x: 250, y: 480),
                controlPoint1: CGPoint(x: 90, y: 530),
                controlPoint2: CGPoint(x: 260, y: 540))
                    
            createDashedLine(from: CGPoint(x: 250, y: 370),
                to: CGPoint(x: 250, y: 480))
                    
            createDashedCurve(from: CGPoint(x: 215.1, y: 438.75),
                to: CGPoint(x: 202.5, y: 454.5),
                controlPoint1: CGPoint(x: 191.25, y: 432.75),
                controlPoint2: CGPoint(x: 175.5, y: 452))

            createDashedCurve(from: CGPoint(x: 185.5, y: 470.25),
                to: CGPoint(x: 198.1, y: 454.5),
                controlPoint1: CGPoint(x: 209.35, y: 479.25),
                controlPoint2: CGPoint(x: 225.1, y: 459))
            
        case "ل":
            createDashedCurve(from: CGPoint(x: 170, y: 450),
                to: CGPoint(x: 250, y: 460),
                controlPoint1: CGPoint(x: 120, y: 550),
                controlPoint2: CGPoint(x: 265, y: 560))
                        
            createDashedLine(from: CGPoint(x: 250, y: 340),
                to: CGPoint(x: 250, y: 460))

        case "م":
            createDashedCurve(from: CGPoint(x: 240, y: 430),
                to: CGPoint(x: 190, y: 380),
                controlPoint1: CGPoint(x: 320, y: 430),
                controlPoint2: CGPoint(x: 230, y: 290))
                            
            createDashedLine(from: CGPoint(x: 180, y: 430),
                to: CGPoint(x: 240, y: 430))
            
            createDashedLine(from: CGPoint(x: 180, y: 430),
                to: CGPoint(x: 180, y: 550))

        case "ن":
            createDashedCurve(from: CGPoint(x: 160, y: 390),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 60, y: 550),
                controlPoint2: CGPoint(x: 340, y: 550))
            
            createDot(at: CGPoint(x: 200, y: 360))
    
        case "ه":
            createDashedCurve(from: CGPoint(x: 197, y: 370),
                to: CGPoint(x: 200, y: 370),
                controlPoint1: CGPoint(x: 60, y: 530),
                controlPoint2: CGPoint(x: 340, y: 530))
        
        case "و":
            createDashedCurve(from: CGPoint(x: 230, y: 350),
                to: CGPoint(x: 280, y: 420),
                controlPoint1: CGPoint(x: 160, y: 350),
                controlPoint2: CGPoint(x: 160, y: 500))
                        
            createDashedCurve(from: CGPoint(x: 130, y: 510),
                to: CGPoint(x: 230, y: 350),
                controlPoint1: CGPoint(x: 320, y: 530),
                controlPoint2: CGPoint(x: 300, y: 345))

        
        case "ي":
            // Create the main curve for "ي"
            createDashedCurve(from: CGPoint(x: 290, y: 350),
                to: CGPoint(x: 250, y: 420),
                controlPoint1: CGPoint(x: 210, y: 310),
                controlPoint2: CGPoint(x: 130, y: 400))
                    
            createDashedCurve(from: CGPoint(x: 130, y: 420),
                to: CGPoint(x: 250, y: 420),
                controlPoint1: CGPoint(x: 60, y: 560),
                controlPoint2: CGPoint(x: 400, y: 475))
            // Add two dots below the curve
            createDot(at: CGPoint(x: 190, y: 520))
            createDot(at: CGPoint(x: 230, y: 520))
        
        case "ص":
            // Center of the screen
            let centerX = view.bounds.midX
            let centerY = view.bounds.midY

            // Offset to center the points relative to the screen
            let offsetX = -337.0 + centerX
            let offsetY = -201.0 + centerY

            // First curve
            createDashedCurve(
                from: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                to: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                controlPoint1: CGPoint(x: 409 + offsetX, y: 110 + offsetY),
                controlPoint2: CGPoint(x: 491 + offsetX, y: 219 + offsetY)
            )

            createDashedCurve(
                from: CGPoint(x: 343 + offsetX, y: 177 + offsetY),
                to: CGPoint(x: 248 + offsetX, y: 194 + offsetY),
                controlPoint1: CGPoint(x: 358 + offsetX, y: 272 + offsetY),
                controlPoint2: CGPoint(x: 213 + offsetX, y: 259 + offsetY)
            )
                    
        case "ض":
            // Center of the screen
            let centerX = view.bounds.midX
            let centerY = view.bounds.midY
            // Offset to center the points relative to the screen
            let offsetX = -337.0 + centerX
            let offsetY = -201.0 + centerY

            createDashedCurve(
                from: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                to: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                controlPoint1: CGPoint(x: 409 + offsetX, y: 110 + offsetY),
                controlPoint2: CGPoint(x: 491 + offsetX, y: 219 + offsetY)
            )

            createDashedCurve(
                from: CGPoint(x: 343 + offsetX, y: 177 + offsetY),
                to: CGPoint(x: 248 + offsetX, y: 194 + offsetY),
                controlPoint1: CGPoint(x: 358 + offsetX, y: 272 + offsetY),
                controlPoint2: CGPoint(x: 213 + offsetX, y: 259 + offsetY)
            )
            createDot(at: CGPoint(x: 385 + offsetX, y: 135 + offsetY))
                    
        case "غ":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            let offsetX = centerX - 337.0
            let offsetY = centerY - 267.0

            // Adjusted curves for "غ"
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 197 + offsetY),
                to: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                controlPoint1: CGPoint(x: 303 + offsetX, y: 121 + offsetY),
                controlPoint2: CGPoint(x: 268 + offsetX, y: 254 + offsetY)
            )
                    
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                to: CGPoint(x: 396 + offsetX, y: 360 + offsetY),
                controlPoint1: CGPoint(x: 259 + offsetX, y: 243 + offsetY),
                controlPoint2: CGPoint(x: 256 + offsetX, y: 401 + offsetY)
            )

            // Dot for "غ" moved up slightly
            createDot(at: CGPoint(x: 326 + offsetX, y: 145 + offsetY))

        case "ع":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            let offsetX = centerX - 337.0
            let offsetY = centerY - 267.0

            // Adjusted curves for "ع"
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 197 + offsetY),
                to: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                controlPoint1: CGPoint(x: 303 + offsetX, y: 121 + offsetY),
                controlPoint2: CGPoint(x: 268 + offsetX, y: 254 + offsetY)
            )
                    
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                to: CGPoint(x: 396 + offsetX, y: 360 + offsetY),
                controlPoint1: CGPoint(x: 259 + offsetX, y: 243 + offsetY),
                controlPoint2: CGPoint(x: 256 + offsetX, y: 401 + offsetY)
            )

        case "ظ":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            // Scaling factor to make the letter slightly bigger
            let scale: CGFloat = 1.5 // Scale up by 10%

            // Original center of the points
            let originalCenterX: CGFloat = 284.0
            let originalCenterY: CGFloat = 210.0

            // Offsets to center the letter and adjust position
            let offsetX = centerX - originalCenterX - 30.0 // Shift 10 points to the left
            let offsetY = centerY - originalCenterY + 40.0 // Move 10 points lower

            // Helper function to scale points relative to original center
            func scalePoint(x: CGFloat, y: CGFloat) -> CGPoint {
                let scaledX = ((x - originalCenterX) * scale) + originalCenterX + offsetX
                let scaledY = ((y - originalCenterY) * scale) + originalCenterY + offsetY
                return CGPoint(x: scaledX, y: scaledY)
            }

            // Adjusted curves and lines for "ظ" with scaling and shifting
            createDashedCurve(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 210),
                controlPoint1: scalePoint(x: 332, y: 133),
                controlPoint2: scalePoint(x: 437, y: 239)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 267, y: 210)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 110)
            )
                    
            // Adjusted dot position with scaling and shifting
            createDot(at: scalePoint(x: 328, y: 156))

        case "ط":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            // Scaling factor to make the letter slightly bigger
            let scale: CGFloat = 1.5 // Scale up by 10%

            // Original center of the points
            let originalCenterX: CGFloat = 284.0
            let originalCenterY: CGFloat = 210.0

            // Offsets to center the letter and adjust position
            let offsetX = centerX - originalCenterX - 30.0 // Shift 10 points to the left
            let offsetY = centerY - originalCenterY + 40.0 // Move 10 points lower

            // Helper function to scale points relative to original center
            func scalePoint(x: CGFloat, y: CGFloat) -> CGPoint {
                let scaledX = ((x - originalCenterX) * scale) + originalCenterX + offsetX
                let scaledY = ((y - originalCenterY) * scale) + originalCenterY + offsetY
                return CGPoint(x: scaledX, y: scaledY)
            }

            // Adjusted curves and lines for "ظ" with scaling and shifting
            createDashedCurve(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 210),
                controlPoint1: scalePoint(x: 332, y: 133),
                controlPoint2: scalePoint(x: 437, y: 239)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 267, y: 210)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 110)
            )
        default:
            break
        }
    }

    func createDashedLine(from start: CGPoint, to end: CGPoint) {
        let segment = UIBezierPath()
        segment.move(to: start)
        segment.addLine(to: end)

        let layer = createDashedLayer(for: segment)
        dashSegments.append((path: segment, layer: layer))
    }

    func createDashedCurve(from start: CGPoint, to end: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        let curve = UIBezierPath()
        curve.move(to: start)
        curve.addCurve(to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2)

        let layer = createDashedLayer(for: curve)
        dashSegments.append((path: curve, layer: layer))
    }

    func createDot(at point: CGPoint) {
        let dot = UIBezierPath()
        dot.addArc(withCenter: point, radius: 6.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)

        let layer = CAShapeLayer()
        layer.path = dot.cgPath
        layer.strokeColor = UIColor.label.cgColor
        layer.fillColor = UIColor.label.cgColor
        view.layer.addSublayer(layer)
        
        view.layer.insertSublayer(drawnLayer, at: UInt32(view.layer.sublayers?.count ?? 0))
    }

    func createDashedLayer(for path: UIBezierPath) -> CAShapeLayer {
        let dashedLayer = CAShapeLayer()
        dashedLayer.path = path.cgPath
        dashedLayer.strokeColor = UIColor.label.cgColor
        dashedLayer.lineWidth = 9.0
        dashedLayer.lineDashPattern = [8, 4]
        dashedLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dashedLayer)
        
        view.layer.insertSublayer(drawnLayer, above: dashedLayer)

        return dashedLayer
    }

    func loadNextLetter() {
        submitButton.isEnabled = false

        if currentLetterIndex < currentLetters.count {
            resetDrawing()
            instructionsLabel.text = "Lesson \(currentLessonIndex + 1): Trace the letter \(currentLetters[currentLetterIndex])"
            createLetterPath(for: currentLetters[currentLetterIndex])
            progressView.progress = Float(currentLetterIndex + 1) / Float(currentLetters.count)
        } else {
            // All letters in the current lesson are completed
            handleTutorialCompletion()
        }
    }


    func resetDrawing() {
        // Clear the drawn path
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        
        // Remove all dashed line layers
        for segment in dashSegments {
            segment.layer.removeFromSuperlayer()
        }
        dashSegments.removeAll()

        // Remove all sublayers (this includes the dots and other shape layers)
        for layer in view.layer.sublayers ?? [] {
            if let shapeLayer = layer as? CAShapeLayer, shapeLayer != drawnLayer {
                shapeLayer.removeFromSuperlayer()  // Keep drawnLayer intact
            }
        }

        // Recreate the bounding box to ensure it stays visible
        setupBoundingBox()

        // Reset button states
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }
    

    func navigateToHome() {
        if let navigationController = self.navigationController {
            // Find HomeViewController in the navigation stack
            if let homeVC = navigationController.viewControllers.first(where: { $0 is HomeViewController }) as? HomeViewController {
                homeVC.markLessonAsComplete(lesson: currentLessonIndex + 1)
            }
            navigationController.popToRootViewController(animated: true)
        }
    }


    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        drawnPath.move(to: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)

        // Ensure the point is within the bounding box
        if let boundingBoxPath = boundingBoxLayer.path, boundingBoxPath.contains(point) {
            // Check all segments to see if the user is touching any segment
            for segment in dashSegments {
                let segmentPath = segment.path.cgPath
                if segmentPath.contains(point) {
                    // Change the specific segment's color to green
                    segment.layer.strokeColor = UIColor.green.cgColor
                }
            }

            // Update the user's drawn path (normal tracing)
            drawnPath.addLine(to: point)
            drawnLayer.path = drawnPath.cgPath
            touchCoordinates.append((x: Double(point.x), y: Double(point.y)))

            if !submitButton.isEnabled {
                submitButton.isEnabled = true
                clearButton.isEnabled = true
            }
        } else {
            print("Touch point is outside the bounding box:", point)
        }
    }


    
    func viewToImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            // Fill the entire context with black color
            context.setFillColor(UIColor.black.cgColor)
            context.fill(view.bounds)
        }
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func extractFeatures(from image: UIImage) -> [Double] {
        guard let cgImage = image.cgImage else {
            print("Error: CGImage is nil.")
            return []
        }

        let targetWidth = 32
        let targetHeight = 32
        let pixelCount = targetWidth * targetHeight

        // Ensure the image has the correct dimensions
        if Int(image.size.width) != targetWidth || Int(image.size.height) != targetHeight {
            print("Warning: Image dimensions are incorrect. Expected \(targetWidth)x\(targetHeight), got \(Int(image.size.width))x\(Int(image.size.height)).")
            return []
        }
        
        // Create a buffer for grayscale pixel data
        var pixelData = [UInt8](repeating: 0, count: pixelCount)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixelData,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("Error: Could not create CGContext for feature extraction.")
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Map pixel values to a normalized [0, 1] range
        let features = pixelData.map { Double($0) }
        if features.count != pixelCount {
            print("Warning: Feature vector length is \(features.count), expected \(pixelCount).")
        }
        
        return features
    }



    @objc private func submitButtonTapped(_ sender: UIButton) {
        guard let boundingBox = boundingBoxLayer.path?.boundingBox else {
            print("Bounding box is not available")
            return
        }
        
        hideDashedLines()
        
        // Add a short delay so dashed lines are fully hidden before capturing png
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let capturedImage = self.viewToImage() else {
                print("Failed to capture image")
                self.showDashedLines()
                return
            }
            
            guard let croppedImage = self.cropImageToBoundingBox(capturedImage, boundingBox: boundingBox) else {
                print("Failed to crop image to bounding box")
                self.showDashedLines()
                return
            }
            
            self.showDashedLines()
            
            let features = self.extractFeatures(from: croppedImage)
            
            let label = self.currentLetters[self.currentLetterIndex]
            self.tutorialData.append((features: features, label: label))
            
            let filename = "user_letter_\(self.currentLetterIndex).png"
            self.client.uploadPNG(image: croppedImage, filename: filename) { success, error in
                DispatchQueue.main.async {
                    if success {
                    } else {
                        print("Failed to upload cropped image for letter \(label): \(error ?? "Unknown error")")
                        self.showAlert(title: "Upload Failed", message: error ?? "Unknown error")
                    }
                }
            }
            
            self.currentLetterIndex += 1
            self.loadNextLetter()
        }
    }

    func cropImageToBoundingBox(_ image: UIImage, boundingBox: CGRect) -> UIImage? {
        // Adjust the bounding box to slightly crop inside the green border
        let scale = UIScreen.main.scale
        let margin: CGFloat = 2.0 // Adjust this to fine-tune how much inside the border you crop
        let scaledBoundingBox = CGRect(
            x: (boundingBox.origin.x + margin) * scale,
            y: (boundingBox.origin.y + margin) * scale,
            width: (boundingBox.width - 2 * margin) * scale,
            height: (boundingBox.height - 2 * margin) * scale
        )

        // Ensure the bounding box is within the image bounds
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: scaledBoundingBox) else {
            print("Failed to crop image to bounding box")
            return nil
        }

        let targetSize = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        UIImage(cgImage: croppedCGImage).draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }

    @objc private func clearButtonTapped(_ sender: UIButton) {
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }

    func showPostTutorialOptions() {
        let alert = UIAlertController(title: "Tutorial Complete", message: "What would you like to do next?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Learn Again", style: .default, handler: { _ in
            self.restartTutorial()
        }))

        alert.addAction(UIAlertAction(title: "Take Quiz", style: .default, handler: { _ in
            self.navigateToQuiz()
        }))

        alert.addAction(UIAlertAction(title: "Go Home", style: .cancel, handler: { _ in
            self.navigationController?.popToRootViewController(animated: true)
        }))

        self.present(alert, animated: true)
    }

    func navigateToQuiz() {
        if let quizViewController = storyboard?.instantiateViewController(withIdentifier: "QuizViewController") as? QuizViewController {
            // Pass the current lesson index + 1 to match 1-based lesson numbering
            quizViewController.currentLesson = currentLessonIndex + 1
            navigationController?.pushViewController(quizViewController, animated: true)
        }
    }

    func restartTutorial() {
        currentLetterIndex = 0
        progressView.progress = 0.0
        progressLabel.text = ""
        loadNextLetter()
        onLessonComplete?()
    }

    func handleTutorialCompletion() {
        // Step 1: Clear and animate the instructions label
        instructionsLabel.text = "" // Clear the current text
        typewriterEffect(instructionsLabel, text: "Learning your handwriting style...", characterDelay: 0.1)
        
        // Step 2: Start the activity indicator
        activityIndicator.startAnimating()
        
        // Step 3: Upload user data and train the model
        uploadUserDataAndTrainModel()
        
        onLessonComplete?()

    }

    // MARK: - Upload and Train Logic
    private func uploadUserDataAndTrainModel() {
        client.prepareUserDataAndUpload(tutorialData: tutorialData, dsid: 1) { [weak self] success, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                defer { self.activityIndicator.stopAnimating() } // Always stop the activity indicator
                
                if success {
                    print("Data uploaded successfully. Training model...")
                    self.trainModel(dsid: 1)
                } else {
                    print("Failed to upload user data: \(error ?? "Unknown error")")
                    self.showAlert(title: "Data Upload Failed", message: error ?? "Unknown error")
                }
            }
        }
    }

    private func trainModel(dsid: Int) {
        client.trainModel(dsid: dsid) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Model trained successfully.")
                    self.progressLabel.text = "Model trained successfully!"
                    self.showPostTutorialOptions()
                    self.onLessonComplete?() // Notify HomeViewController of completion
                case .failure(let error):
                    print("Model training failed: \(error.localizedDescription)")
                    self.showAlert(title: "Training Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Typewriter Effect Animation
    private func typewriterEffect(_ label: UILabel, text: String, characterDelay: TimeInterval) {
        label.text = "" // Clear the label before animating
        var charIndex = 0.0

        for letter in text {
            DispatchQueue.main.asyncAfter(deadline: .now() + charIndex * characterDelay) {
                label.text?.append(letter)
            }
            charIndex += 1
        }
    }


    func hideDashedLines() {
        for segment in dashSegments {
            segment.layer.isHidden = true
        }
    }

    func showDashedLines() {
        for segment in dashSegments {
            segment.layer.isHidden = false
        }
    }
    
    
    func fadeInLabel(_ label: UILabel, duration: TimeInterval = 1.0) {
        label.alpha = 0.0
        UIView.animate(withDuration: duration) {
            label.alpha = 1.0
        }
    }
    

    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true)
    }
}
