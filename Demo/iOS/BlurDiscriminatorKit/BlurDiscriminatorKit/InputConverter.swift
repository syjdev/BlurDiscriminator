//
//  InputConverter.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/10/06.
//

import Foundation
import CoreGraphics


internal protocol InputConverter: AnyObject {
    func convert(cgImage: CGImage) -> Data?
}
