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
#include <cstring>

@interface InterpreterWrapper ()

{
    std::unique_ptr<tflite::Interpreter> _interpreter;
    std::unique_ptr<tflite::FlatBufferModel> _model;
    tflite::ops::builtin::BuiltinOpResolver _resolver;
}

@end


@implementation InterpreterWrapper

- (instancetype)initWithModelPath:(NSString *)modelPath andNumberOfThread:(UInt8)numberOfThread {
    self = [super init];
    if (self) {
        _model = tflite::FlatBufferModel::BuildFromFile([modelPath UTF8String], nullptr);
        NSAssert(_model, @"failed to build model. maybe modelPath was invalid.");

        tflite::InterpreterBuilder(*_model, _resolver)(&_interpreter);
        NSAssert(_interpreter, @"failed to build interpreter. maybe tflite model was invalid.");

        _interpreter->SetNumThreads(numberOfThread);

        // 텐서 할당은 입력 크기가 변하지 않는 한 최초 1회면 충분하다.
        TfLiteStatus allocationStatus = _interpreter->AllocateTensors();
        NSAssert(allocationStatus == kTfLiteOk, @"failed to allocate tensors.");
        (void)allocationStatus;
    }
    return self;
}

- (nullable NSData *)interpretWithInputData:(NSData *)inputData {
    // Copy raw bytes so the wrapper works for both float32 and uint8 models.
    // The converters on the Swift side must produce/consume the matching layout.
    TfLiteTensor *inputTensor = _interpreter->input_tensor(0);
    NSAssert(inputTensor != nullptr && inputData.length == inputTensor->bytes,
             @"input size mismatch. expected %zu bytes, got %lu.",
             inputTensor->bytes, (unsigned long)inputData.length);
    if (inputTensor == nullptr || inputData.length != inputTensor->bytes) {
        return nil;
    }

    std::memcpy(inputTensor->data.raw, inputData.bytes, inputTensor->bytes);

    if (_interpreter->Invoke() != kTfLiteOk) {
        return nil;
    }

    const TfLiteTensor *outputTensor = _interpreter->output_tensor(0);
    if (outputTensor == nullptr) {
        return nil;
    }

    return [NSData dataWithBytes:outputTensor->data.raw length:outputTensor->bytes];
}

@end
