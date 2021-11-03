//
//  InterpreterWrapper.h
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/27.
//

#import <Foundation/Foundation.h>


@interface InterpreterWrapper: NSObject

- (instancetype __nonnull)initWithModelPath:(NSString * __nonnull)modelPath andNumberOfThread:(UInt8)numberOfThread;
- (NSData * __nonnull)interpretWithInputData:(NSData * __nonnull)inputData;

@end
