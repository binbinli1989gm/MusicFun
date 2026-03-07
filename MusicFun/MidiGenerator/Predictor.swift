//
//  Predictor.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//
import Foundation

// MARK: - TorchScript model wrapper
class MusicTransformerModel {
    
    private var module: MidiTorchModule = {
        if let filePath = Bundle.main.path(forResource: "music_transformer", ofType: "ptl"),
           let module = MidiTorchModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Music model FILE not found.")
        }
    }()
    
    /// Generate a music sequence from a primer
    func generate(primer: [Int32], targetLength: Int) -> [Int32] {
        
        var inputTensor = primer
        
        for _ in 0..<targetLength  {
            // 1. Convert Swift array to Torch Tensor via the wrapper
            // 2. Run inference to get probabilities
            // 3. Sample or take the ArgMax for the next token
            
            let inputNumbers = inputTensor.map { NSNumber(value: $0) }
            let nextToken : NSNumber = module.predict(inputNumbers)
            let nextTokenInt = nextToken.int32Value
            inputTensor.append(nextTokenInt)
        }
        
        return inputTensor
    }
    
    func startAIGeneration(primer: [Int32]) -> [Int32] {
        
        let numberArray: [NSNumber] = [60, 62, 64, 65, 67, 69, 71, 72] // C major scale
        
//        let numberArray: [NSNumber] = primer.map { NSNumber(value: $0) }
        
        let tokens = self.module.generateA2(numberArray, steps: 500, temperature: 1.2)
        let intTokens = tokens.map { Int32(truncating: $0) }
        
        print("intTokens \(intTokens)")
        
        return intTokens
        
    }
}
