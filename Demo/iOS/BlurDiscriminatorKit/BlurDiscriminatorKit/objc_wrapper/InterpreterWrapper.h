//
//  InterpreterWrapper.h
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InterpreterWrapper: NSObject

- (instancetype)initWithModelPath:(NSString *)modelPath andNumberOfThread:(UInt8)numberOfThread;
- (nullable NSData *)interpretWithInputData:(NSData *)inputData;

@end

NS_ASSUME_NONNULL_END
