#import "TorchModule.h"
#import <LibTorch/LibTorch.h>

@implementation TorchModule {
 @protected
  torch::jit::script::Module _impl;
}

- (nullable instancetype)initWithFileAtPath:(NSString*)filePath {
  self = [super init];
  if (self) {
    try {
      auto qengines = at::globalContext().supportedQEngines();
      if (std::find(qengines.begin(), qengines.end(), at::QEngine::QNNPACK) != qengines.end()) {
        at::globalContext().setQEngine(at::QEngine::QNNPACK);
      }
      _impl = torch::jit::load(filePath.UTF8String);
      _impl.eval();
    } catch (const std::exception& exception) {
      NSLog(@"%s", exception.what());
      return nil;
    }
  }
  return self;
}

@end

@implementation MidiTorchModule

- (NSNumber *)predict:(NSArray<NSNumber *> *)inputSequence {
    
    std::cout << "Hello from C++ logic" << std::endl;
    
    try {
        // 1. Convert Swift's NSArray to a C++ vector of 64-bit integers
        int64_t count = inputSequence.count;
        std::vector<int64_t> v;
        for (NSNumber *number in inputSequence) {
            v.push_back([number longLongValue]);
        }

        // 2. Create a Tensor [Batch=1, SeqLen=N] from the vector
        // at::kLong matches the expected LongTensor type in PyTorch
        at::Tensor tensor = torch::from_blob(v.data(), {1, count}, at::kLong).clone();

        // 3. Run Inference (Forward Pass)
        // This produces a tensor of shape [1, count, 388] (logits for each note)
        auto output = _impl.forward({tensor}).toTensor();
        
        // 4. Get the prediction for the VERY LAST token in the sequence
        // We select dimension 1 (sequence length) and index (count - 1)
        at::Tensor lastTokenLogits = output.select(1, count - 1);
        
        // 5. Greedy Selection (Argmax)
        // Find the index of the highest probability
        auto nextTokenId = lastTokenLogits.argmax(1).item<int32_t>();
        
        return [NSNumber numberWithInt:nextTokenId];
        
    } catch (const std::exception& exception) {
        NSLog(@"Inference Error: %s", exception.what());
        return @(-1); // Return an error code if inference fails
    }
}

- (NSArray<NSNumber *> *)generateA2:(NSArray<NSNumber *> *)primer
                            steps:(int)steps
                      temperature:(float)temp {
    
    // 1. Convert Swift primer to C++ vector
    std::vector<int64_t> sequence;
    for (NSNumber *n in primer) {
        sequence.push_back([n longLongValue]);
    }

    // Move to evaluation mode
    _impl.eval();

    for (int i = 0; i < steps; i++) {
        // 2. Create Input Tensor [1, SeqLength]
        // We use the last 1024 tokens because that's our model's limit (Relative Position E)
        int startIdx = std::max(0, (int)sequence.size() - 1024);
        std::vector<int64_t> context(sequence.begin() + startIdx, sequence.end());
        
        at::Tensor input = torch::from_blob(context.data(), {1, (int64_t)context.size()}, at::kLong).clone();

        // 3. Forward Pass
        auto output = _impl.forward({input}).toTensor(); // Shape: [1, Seq, 416]
        
        // 4. Get Logits for the very last token
        at::Tensor logits = output.select(1, output.size(1) - 1); // Shape: [416]

        // 5. Apply Temperature Sampling
        // Formula: Softmax(logits / temperature)
        logits = logits.div(temp);
        at::Tensor probs = torch::softmax(logits, 0);

        // 6. Multinominal Sample (Pick a note based on probability, not just the max)
        at::Tensor nextTokenTensor = torch::multinomial(probs, 1);
        int32_t nextToken = nextTokenTensor.item<int32_t>();

        // 7. Append to sequence
        sequence.push_back(nextToken);
        
        // Stop if we hit an End-of-Track token (if your vocab has one)
        // if (nextToken == EOT_TOKEN) break;
    }

    // 8. Convert back to NSArray for Swift
    NSMutableArray *result = [NSMutableArray array];
    for (int64_t val : sequence) {
        [result addObject:@(val)];
    }
    
    return result;
}

@end

