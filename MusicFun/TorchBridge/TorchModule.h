#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TorchModule : NSObject

- (nullable instancetype)initWithFileAtPath:(NSString*)filePath
    NS_SWIFT_NAME(init(fileAtPath:))NS_DESIGNATED_INITIALIZER;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface MidiTorchModule : TorchModule

- (NSNumber *)predict:(NSArray<NSNumber *> *)inputSequence;
- (NSArray<NSNumber *> *)generateA2:(NSArray<NSNumber *> *)primer steps:(int)steps temperature:(float)temp;

@end

NS_ASSUME_NONNULL_END
