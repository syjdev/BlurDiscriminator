//
//  OutputConverter.swift
//  BlurDiscriminatorKit
//
//  Created by syjdev on 2021/11/03.
//

import Foundation


internal protocol OutputConverter: AnyObject {
    func convert(data: Data) -> BlurObservation?
}
