//
//  BlurDiscriminatorError.swift
//  BlurDiscriminator-iOS
//
//  Created by syjdev on 2021/01/23.
//

import Foundation

enum BlurDiscriminatorError: Error {
    case mtlDeviceWasCorrupted
    case unsupportedDevice
    case shaderFunctionWasCorrupted
    case commandWasCorrupted
    case failedToMakeTexture
}
