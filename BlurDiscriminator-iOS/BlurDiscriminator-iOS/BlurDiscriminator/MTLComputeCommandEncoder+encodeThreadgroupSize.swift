//
//  MTLComputeCommandEncoder+encodeThreadgroupSize.swift
//  BlurDiscriminator-iOS
//
//  Created by syjdev on 2021/01/23.
//

import Metal


extension MTLComputeCommandEncoder {
    /// calculate a suitable threadgroups, then call dispatchThreadgroups.
    ///
    /// You can see a apple's guide,  "https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes"
    ///
    func dispatchThreadgroups(texture: MTLTexture, computePipelineState: MTLComputePipelineState) {
        let width = computePipelineState.threadExecutionWidth
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        
        let threadgroupsPerGrid = MTLSize(width: (texture.width + width - 1) / width,
                                          height: (texture.height + height - 1) / height,
                                          depth: 1)
        
        self.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
}
