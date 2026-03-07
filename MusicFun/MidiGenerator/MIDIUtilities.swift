//
//  MIDIUtilities.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//


import AVFoundation

class MidiWriter {
    
    static let shared = MidiWriter()
    
    /// Save an array of MIDI note numbers as a MIDI file
    func saveMidi(sequence: [Int32], filename: String) -> URL {

        var musicSequence: MusicSequence? = nil
           NewMusicSequence(&musicSequence)
           
           var track: MusicTrack? = nil
           MusicSequenceNewTrack(musicSequence!, &track)
           
           var currentTime: MusicTimeStamp = 0
           var currentVelocity: UInt8 = 64
           
           // Track active notes (note -> startTime)
           var activeNotes: [UInt8: MusicTimeStamp] = [:]
           
           for token in sequence {
               
               switch token {
                   
               // NOTE ON
               case 0...127:
                   let noteNum = UInt8(token)
                   activeNotes[noteNum] = currentTime
                   
                   
               // NOTE OFF
               case 128...255:
                   let noteNum = UInt8(token - 128)
                   
                   if let startTime = activeNotes[noteNum] {
                       
                       let duration = Float(currentTime - startTime)
                       
                       var message = MIDINoteMessage(
                           channel: 0,
                           note: noteNum,
                           velocity: currentVelocity,
                           releaseVelocity: 0,
                           duration: duration > 0 ? duration : 0.05
                       )
                       
                       MusicTrackNewMIDINoteEvent(track!, startTime, &message)
                       
                       activeNotes.removeValue(forKey: noteNum)
                   }
                   
                   
               // TIME SHIFT
               case 256...383:
                   let shift = Double(token - 256) * 0.01
                   currentTime += shift
                   
                   
               // VELOCITY CHANGE
               case 384...415:
                   currentVelocity = UInt8((token - 384) * 4)
                   
                   
               default:
                   break
               }
           }
           
           
           // ✅ FIX: Close any notes that never received NOTE OFF
           for (noteNum, startTime) in activeNotes {
               
               let duration = Float(currentTime - startTime)
               
               var message = MIDINoteMessage(
                   channel: 0,
                   note: noteNum,
                   velocity: currentVelocity,
                   releaseVelocity: 0,
                   duration: duration > 0 ? duration : 0.5
               )
               
               MusicTrackNewMIDINoteEvent(track!, startTime, &message)
           }
           
           
           // Save file
           let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
           let fileURL = docs.appendingPathComponent(filename)
           
           MusicSequenceFileCreate(
               musicSequence!,
               fileURL as CFURL,
               .midiType,
               .eraseFile,
               480
           )
           
           
           // Optional cleanup
           DisposeMusicSequence(musicSequence!)
          
        
        print("Saved MIDI file to:", fileURL.path)
        
        return fileURL
        
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
