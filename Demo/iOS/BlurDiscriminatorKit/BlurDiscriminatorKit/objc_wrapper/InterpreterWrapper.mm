//
//  InterpreterWrapper.mm
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/09/27.
//

#import "InterpreterWrapper.h"

#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"


@interface InterpreterWrapper ()

{
    std::unique_ptr<tflite::Interpreter> _interpreter;
    std::unique_ptr<tflite::FlatBufferModel> _model;
    tflite::ops::builtin::BuiltinOpResolver _resolver;
}

@end


@implementation InterpreterWrapper

- (instancetype __nonnull)initWithModelPath:(NSString * __nonnull)modelPath andNumberOfThread:(UInt8)numberOfThread {
    self = [super init];

    _model = tflite::FlatBufferModel::BuildFromFile([modelPath UTF8String], nullptr);
    NSAssert(_model, @"failed to build model. maybe modelPath was invalid.");
    
    tflite::InterpreterBuilder(*_model, _resolver)(&_interpreter);
    NSAssert(_interpreter, @"failed to build interpreter. maybe tflite model was invalid.");
    
    _interpreter->SetNumThreads(numberOfThread);
    
    return self;
}


- (NSData * __nonnull)interpretWithInputData:(NSData * __nonnull)inputData {
    _interpreter->AllocateTensors();
    
    auto* input = _interpreter->typed_input_tensor<UInt8>(0);
    UInt8 inputBuffer[inputData.length];
    [inputData getBytes:inputBuffer length:inputData.length];
    std::memcpy(input, inputBuffer, inputData.length);
    _interpreter->Invoke();
    auto outputBuffer = _interpreter->typed_output_tensor<UInt8>(0);

    return [NSData dataWithBytes:outputBuffer length:inputData.length];
}

@end
