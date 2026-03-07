//
//  TaskManager.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//

import AVFoundation

protocol MidiSequencerDelegate: AnyObject {
    func sequencerDidFinishPlaying()
    func sequencerStartPlaying()
}

class TaskController: NSObject {
    
    static let shared = TaskController()
    
    weak var delegate: MidiSequencerDelegate?
    
    var isPlaying = false
    
    public var noteTapped : [Int32] = []
    
    private lazy var midiPlayer : AdvancedMIDIPlayer = {
        return AdvancedMIDIPlayer.shared
    }()
    
    private lazy var transformer : MusicTransformerModel = {
        return MusicTransformerModel()
    }()
    
    private lazy var midiSaver : MidiWriter = {
        return MidiWriter.shared
    }()
    
    var completionTimer: Timer?
    
    
    func generateAIMusic() {
        
        if noteTapped.count < 3 {
            return
        }
        
        let inttok = transformer.startAIGeneration(primer: noteTapped)
        let midiURL = MidiWriter.shared.saveMidi(sequence: inttok, filename: "AI_Piano")
        
        guard let bankURL = Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2") else {
            print("Error: SoundBank not found in bundle.")
            return
        }
        
        isPlaying = true
        self.delegate?.sequencerStartPlaying()
        
        midiPlayer.loadAndPlayMIDI(midiURL: midiURL, soundBankURL: bankURL)

        startCompletionTimer()
        
        noteTapped = []
        
    }
    
    func addNote(note: Int32) {
        noteTapped.append(note)
    }
    
    func stopMusic() {
        self.midiPlayer.stop()
    }
    
    func startCompletionTimer() {
            // Invalidate any existing timer
            completionTimer?.invalidate()
            
            // Check every 0.1 seconds if it's still playing
            completionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self, let seq = midiPlayer.sequencer else { return }
                
                // Check if sequencer has stopped playing
                if !seq.isPlaying {
                    timer.invalidate()
                    self.handlePlaybackEnded()
                    
                }
            }
        }

        func handlePlaybackEnded() {
            print("Sequencer has finished the MIDI file!")
            
            isPlaying = false
            self.delegate?.sequencerDidFinishPlaying()
        }
    
}

