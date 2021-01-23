//
//  ShaderFunctions.swift
//  BlurDiscriminator-iOS
//
//  Created by syjdev on 2021/01/23.
//

import Foundation


internal let shaderFunction = """
using namespace metal;
constant float3 rgbDegree = float3(0.3333, 0.3333, 0.3333);
kernel void changeToGrayscale(texture2d<float, access::read>  input   [[ texture(0) ]],
                              texture2d<float, access::write> output  [[ texture(1) ]],
                              uint2                           gid     [[ thread_position_in_grid ]])
{
    if((gid.x < output.get_width()) && (gid.y < output.get_height()))
    {
        float4 pixel  = input.read(gid);
        float grayscaledRgb  = dot(pixel.rgb, rgbDegree);
        float4 grayscaledPixel = float4(grayscaledRgb, grayscaledRgb, grayscaledRgb, 1.0) * 255.0;
        output.write(grayscaledPixel, gid);
    }
}
"""
