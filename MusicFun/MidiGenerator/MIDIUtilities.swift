//
//  MIDIUtilities.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//


import AudioToolbox
import AVFoundation

class MIDIWriter {
    
    // vocabulary constants based on your Python code
    let noteOnRange = 0...127
    let noteOffRange = 128...255
    let timeShiftRange = 256...383
    let velocityRange = 384...415
    
    // DIV scale from your vocabulary (usually 10ms or 0.01s)
    let DIV: Double = 0.01
    
    func createMidiFile(tokens: [Int32], fileName: String) -> URL? {
        var sequence: MusicSequence?
        guard NewMusicSequence(&sequence) == noErr, let seq = sequence else { return nil }
        
        var track: MusicTrack?
        guard MusicSequenceNewTrack(seq, &track) == noErr, let trk = track else { return nil }
        
        var currentTime: MusicTimeStamp = 0.0
        var currentVelocity: UInt8 = 64 // Default starting velocity
        
        // Dictionary to track when a note started so we can calculate its duration
        var activeNotes: [Int: MusicTimeStamp] = [:]
        
        for token in tokens {
            // Adjust for <pad> token if your model uses 1-based indexing
            // (Your Python code does: idx = idx - 1)
            let idx = Int(token) - 1
            if idx < 0 { continue }
            
            if noteOnRange.contains(idx) {
                // Note On: Save the start time
                let noteNumber = idx
                activeNotes[noteNumber] = currentTime
                
            } else if noteOffRange.contains(idx) {
                // Note Off: Find when it started and calculate duration
                let noteNumber = idx - 128
                if let startTime = activeNotes[noteNumber] {
                    let duration = Float32(currentTime - startTime)
                    
                    var message = MIDINoteMessage(
                        channel: 0,
                        note: UInt8(noteNumber),
                        velocity: currentVelocity,
                        releaseVelocity: 0,
                        duration: duration
                    )
                    
                    MusicTrackNewMIDINoteEvent(trk, startTime, &message)
                    activeNotes.removeValue(forKey: noteNumber)
                }
                
            } else if timeShiftRange.contains(idx) {
                // Time Shift: Move the "playhead" forward
                let ticks = Double(idx - 256 + 1)
                currentTime += (ticks * DIV)
                
            } else if velocityRange.contains(idx) {
                // Velocity: Update the volume for the NEXT note
                let velBin = idx - 384
                currentVelocity = UInt8(velBin * 4) // Scaling 32 bins to 128 MIDI range
            }
        }
        
        // Save to File System
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).mid")
        let status = MusicSequenceFileCreate(seq, url as CFURL, .midiType, .eraseFile, 0)
        
        if status == noErr {
            return url
        } else {
            print("Error creating MIDI file: \(status)")
            return nil
        }
    }
}

class AdvancedMIDIPlayer {
    // Audio engine components
    
    static let shared = AdvancedMIDIPlayer()
    
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    public var sequencer: AVAudioSequencer?
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        // 1. Attach the sampler to the engine
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Error details: \(error)")
        }
        
        engine.attach(sampler)
        
        // 2. Connect sampler to the main mixer
        // We use the hardware's output format to ensure compatibility
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(sampler, to: engine.mainMixerNode, format: format)
        
        // 3. Prepare the engine to allocate audio buffers ahead of time
        engine.prepare()
        
        do {
            try engine.start()
            
            print(engine.mainMixerNode.outputFormat(forBus: 0))
            print(engine.outputNode.outputFormat(forBus: 0))
            
            print("✅ Audio Engine Started")
        } catch {
            print("❌ Engine Start Error: \(error.localizedDescription)")
        }
    }
    
    func loadAndPlayMIDI(midiURL: URL, soundBankURL: URL) {
        // Ensure the engine is running (it can stop if the app goes to background)
        if !engine.isRunning { try? engine.start() }
        
        // Stop any current playback to clear the buffer
        stop()
        
        // IMPORTANT: Create a fresh sequencer for every new file
        // to avoid "ghost" track mappings from previous attempts.
        let newSequencer = AVAudioSequencer(audioEngine: engine)
        
        do {
            // STEP A: Load the MIDI File into the new sequencer
            try newSequencer.load(from: midiURL, options: [])
            
            // STEP B: Load the SoundBank into the Sampler
            // 0x79 (121) is standard for Melodic GM; 0x78 (120) is for Drums
            try sampler.loadSoundBankInstrument(at: soundBankURL,
                                                program: 0,
                                                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            
            // STEP C: Map each track to the sampler
            for track in newSequencer.tracks {
                track.destinationAudioUnit = sampler
            }
            
            // STEP D: THE FIX for Error -10852
            // This syncs the sequencer's internal C++ 'impl' with the engine
            newSequencer.prepareToPlay()
            
            // STEP E: Start Playback
            self.sequencer = newSequencer
            try self.sequencer?.start()
            
            print("🎶 Now playing: \(midiURL.lastPathComponent)")
            
        } catch {
            print("❌ Playback failed with error: \(error.localizedDescription)")
            // If it's still -10852, it's often a bit-depth mismatch in the .sf2 file
        }
    }
    
    /// 2. Plays the MIDI file (Fixes Error -10852)
    func play(url: URL) {
        // We create a new sequencer instance for the engine
        self.sequencer = AVAudioSequencer(audioEngine: engine)
        
        do {
            try sequencer?.load(from: url, options: [])
            
            // THE FIX: Route every track in the MIDI file to the Sampler
            for track in sequencer?.tracks ?? [] {
                track.destinationAudioUnit = sampler
            }
            
            sequencer?.prepareToPlay()
            try sequencer?.start()
            print("Playing AI Music...")
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    func stop() {
        if let seq = sequencer, seq.isPlaying {
            seq.stop()
        }
        sequencer = nil // Discarding the old sequencer is the safest way to reset
    }
    
    func setInstrument(_ instrument: GeneralMIDIInstrument) {
        
        guard let soundBankURL = Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2") else {
            print("Error: SoundBank not found in bundle.")
            return
        }
        
        do {
            try sampler.loadSoundBankInstrument(at: soundBankURL,
                                                program: UInt8(instrument.rawValue),
                                                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        } catch {
            print("Error.")
        }
        
        
    }
    
    func playNote(note: UInt8) {
        sampler.startNote(note, withVelocity: 100, onChannel: 0)
    }
    
    func stopNote(note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
    }
    
}


