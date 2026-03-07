//
//  FirstViewController.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//

import UIKit

class FirstViewController: UIViewController, MidiSequencerDelegate {
    
    var musicTasker = TaskController.shared
    let musicGenerateButton = UIButton(type: .system)
    
    func sequencerDidFinishPlaying() {
        DispatchQueue.main.async {
            self.musicGenerateButton.setTitle("Generate Music", for: .normal)
        }
    }
    
    func sequencerStartPlaying() {
        DispatchQueue.main.async {
            MaskView.shared.hide()
            self.musicGenerateButton.setTitle("Stop Music", for: .normal)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackgroundImage()
        self.musicTasker.delegate = self
        
        addPieNoteView()
        addInstrumentSelectionButton()
        
        addAIMusicGenerationButton()
    }
    
    func addInstrumentSelectionButton() {
        
        let button = UIButton(type: .system)
        button.setTitle("Select Instrument", for: .normal)
        
        button.layer.cornerRadius = 10  //Half of width/height for a circle
        button.layer.shadowRadius = 10
        button.layer.shadowOpacity = 0.3
        
        button.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        
        button.frame = CGRectMake(self.view.frame.size.width - 160, 10, 136, 100)
        
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        button.addTarget(self, action: #selector(selectInstrument), for: .touchUpInside)
        view.addSubview(button)
    }
    
    @objc func selectInstrument() {
        let detailVC = MIDIInstrumentViewController()
        self.navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func addAIMusicGenerationButton() {
        
        musicGenerateButton.setTitle("Generate Music", for: .normal)
        
        musicGenerateButton.layer.cornerRadius = 10  //Half of width/height for a circle
        musicGenerateButton.layer.shadowRadius = 10
        musicGenerateButton.layer.shadowOpacity = 0.3
        
        musicGenerateButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        
        musicGenerateButton.frame = CGRectMake(self.view.frame.size.width - 160, self.view.frame.size.height - 200 ,  136 , 100)
        
        musicGenerateButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        musicGenerateButton.addTarget(self, action: #selector(generateMusic), for: .touchUpInside)
        view.addSubview(musicGenerateButton)
    }
    
    @objc func generateMusic() {
        
        MaskView.shared.show(message: "Generating...")
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    // Predict next note using your .ptl model
                    // let nextNote = self?.predictor.predictNextNote(inputSequence: currentSequence)
                self?.musicTasker.generateAIMusic()
                    // Generate and play MIDI
                    // self?.safePlayMidi(note: nextNote)
                    
                    print("✅ Prediction and MIDI handled off-main-thread")
                }
    }
    
    private func setupBackgroundImage() {
        let imageView =  UIImageView(frame: view.bounds)
        imageView.image = UIImage(named: "Back")
        imageView.contentMode = .scaleAspectFill
        view.addSubview(imageView)
    }
    
    private func addPieNoteView() {
        let imageView = PieNoteView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFill
        view.addSubview(imageView)
    }
    
    @objc private func buttonTapped() {
        musicTasker.generateAIMusic()
    }
    
}

class PieNoteView: UIView {
    
    var musicTasker = TaskController.shared
    
    let numberOfSlices = 7
    var player: AdvancedMIDIPlayer =  AdvancedMIDIPlayer.shared
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) {
        fatalError("PieNoteView init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<numberOfSlices {
            let startAngle = CGFloat(i) * 2 * .pi / CGFloat(numberOfSlices) - .pi/2
            let endAngle = CGFloat(i + 1) * 2 * .pi / CGFloat(numberOfSlices) - .pi/2
            
            ctx.move(to: center)
            ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        let dx = point.x - center.x
        let dy = center.y - point.y // UIKit Y-axis is flipped
        
        let angle = atan2(dy, dx) * 180 / .pi
        let adjustedAngle = angle < 0 ? angle + 360 : angle
        let sliceIndex = Int(adjustedAngle / (360.0 / CGFloat(numberOfSlices)))
        
        print("Tapped slice: \(sliceIndex + 1)")
        playNote(for: sliceIndex)
        
    }
    
    // MARK: - Play Note
    func playNote(for slice: Int) {
        let noteNames = ["C", "D", "E", "F", "G", "A", "B"]
        let note = slice % noteNames.count + 60
        
        musicTasker.addNote(note: Int32(note))
        
        self.player.playNote(note: UInt8(note))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.player.stopNote(note: UInt8(note))
        }
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self)
        createFirework(at: location)
    }
    
    func createFirework(at point: CGPoint) {
        // Create emitter layer
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .line
        
        // Create emitter cell
        let cell = CAEmitterCell()
        cell.contents = makeParticleImage()
        
        cell.birthRate = 200        // High number of particles at once
        cell.lifetime = 1.5         // How long they last
        cell.velocity = 100         // Initial speed
        cell.velocityRange = 50     // Variation in speed
        cell.emissionRange = .pi * 2 // 360 degree explosion
        cell.scale = 0.01
        cell.scaleSpeed = -0.02     // Shrink as they disappear
        cell.alphaSpeed = -0.7      // Fade out
        
        emitter.emitterCells = [cell]
        self.layer.addSublayer(emitter)
        
        // Remove emitter after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            emitter.removeFromSuperlayer()
        }
        
    }
    
    private func makeParticleImage() -> CGImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        let colors = [
            UIColor.white.cgColor,
            UIColor.clear.cgColor
        ] as CFArray
        
        let locations: [CGFloat] = [0.0, 0.3, 1.0]
        
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return nil }
        
        let center = CGPoint(x: size.width/2, y: size.height/2)
        
        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: size.width/2,
            options: []
        )
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.cgImage
    }
}
