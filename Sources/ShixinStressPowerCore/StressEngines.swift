// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Darwin
import Metal
import ShixinStressPowerHardwareBridge

public actor StressController {
    private var cpuRun: NativeCPUStressRun?
    private var gpuTask: Task<Void, Never>?
    private var gpuCompletion: DispatchSemaphore?
    private var gpuGeneration: UInt64 = 0
    private var gpuRuntimeFailure: String?
    private var isRunning = false

    public init() {}

    public func start(configuration: StressConfiguration) async throws {
        guard !isRunning else { return }
        guard gpuTask == nil else {
            throw StressError.gpuUnavailable("上一轮 GPU 压力命令仍在安全收尾，请稍后再开始")
        }
        gpuRuntimeFailure = nil
        isRunning = true
        do {
            if configuration.mode == .cpu || configuration.mode == .combined {
                try startCPU(workers: configuration.cpuWorkers)
            }
            if configuration.mode == .gpu || configuration.mode == .combined {
                try startGPU(configuration: configuration)
            }
        } catch {
            cpuRun?.stop()
            cpuRun = nil
            gpuTask?.cancel()
            gpuTask = nil
            gpuCompletion = nil
            gpuRuntimeFailure = nil
            isRunning = false
            throw error
        }
    }

    public func takeRuntimeFailure() -> String? {
        defer { gpuRuntimeFailure = nil }
        return gpuRuntimeFailure
    }

    public func stop() async {
        gpuTask?.cancel()
        cpuRun?.stop()
        var gpuStopped = true
        if let gpuCompletion {
            let result = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    continuation.resume(returning: gpuCompletion.wait(timeout: .now() + 2))
                }
            }
            gpuStopped = result == .success
        }
        cpuRun = nil
        if gpuStopped {
            gpuTask = nil
            gpuCompletion = nil
        } else if let gpuTask {
            let generation = gpuGeneration
            Task { [weak self] in
                _ = await gpuTask.result
                await self?.completeGPUDrain(generation: generation)
            }
        }
        isRunning = false
    }

    private func startCPU(workers: Int) throws {
        cpuRun = NativeCPUStressRun(workers: max(1, workers))
        try cpuRun?.start()
    }

    private func startGPU(configuration: StressConfiguration) throws {
        let engine = try GPUStressEngine(configuration: configuration)
        let completion = DispatchSemaphore(value: 0)
        gpuGeneration &+= 1
        gpuCompletion = completion
        let generation = gpuGeneration
        gpuTask = Task.detached(priority: .utility) { [weak self] in
            defer { completion.signal() }
            if let failure = await engine.run() {
                await self?.recordGPUFailure(failure, generation: generation)
            }
        }
    }

    private func recordGPUFailure(_ message: String, generation: UInt64) {
        guard generation == gpuGeneration, isRunning else { return }
        gpuRuntimeFailure = message
    }

    private func completeGPUDrain(generation: UInt64) {
        guard generation == gpuGeneration else { return }
        gpuTask = nil
        gpuCompletion = nil
    }
}

final class NativeCPUStressRun: @unchecked Sendable {
    private let workers: Int
    private var handle: OpaquePointer?

    init(workers: Int) {
        self.workers = min(128, max(1, workers))
    }

    func start() throws {
        guard let handle = ShixinCPUStressRunCreate(Int32(workers)) else {
            throw StressError.cpuUnavailable("CPU 压力线程创建失败")
        }
        self.handle = handle
        let startedWorkers = Int(ShixinCPUStressRunGetWorkerCount(handle))
        guard startedWorkers == workers else {
            stop()
            throw StressError.cpuUnavailable(
                "CPU 压力线程未完整启动（需要 \(workers)，实际 \(startedWorkers)）"
            )
        }
    }

    func stop() {
        guard let handle else { return }
        ShixinCPUStressRunStop(handle)
        self.handle = nil
    }

    deinit {
        stop()
    }
}

final class GPUStressEngine: @unchecked Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let outputBuffer: MTLBuffer
    private let workItems: Int
    private let iterations: UInt32
    private let maxInFlight = 2

    init(configuration: StressConfiguration) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw StressError.gpuUnavailable("Metal 默认设备不可用")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw StressError.gpuUnavailable("Metal command queue 创建失败")
        }

        let library = try device.makeLibrary(source: GPUStressEngine.shaderSource, options: nil)
        guard let function = library.makeFunction(name: "stress_kernel") else {
            throw StressError.gpuUnavailable("Metal stress kernel 创建失败")
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        guard let preflightBuffer = commandQueue.makeCommandBuffer(),
              let preflightEncoder = preflightBuffer.makeComputeCommandEncoder() else {
            throw StressError.gpuUnavailable("Metal 压力命令预检失败")
        }
        preflightEncoder.endEncoding()
        let workItems = max(1, configuration.gpuWorkItems)
        guard let outputBuffer = device.makeBuffer(length: workItems * MemoryLayout<SIMD4<Float>>.stride, options: .storageModePrivate) else {
            throw StressError.gpuUnavailable("Metal buffer 分配失败")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pipeline = pipeline
        self.outputBuffer = outputBuffer
        self.workItems = workItems
        self.iterations = UInt32(max(1, configuration.gpuIterations))
    }

    func run() async -> String? {
        var pending: [MTLCommandBuffer] = []
        while !Task.isCancelled {
            let failure: String? = autoreleasepool {
                guard let commandBuffer = commandQueue.makeCommandBuffer(),
                      let encoder = commandBuffer.makeComputeCommandEncoder() else {
                    return "Metal 无法继续创建压力命令"
                }
                var localIterations = iterations
                encoder.setComputePipelineState(pipeline)
                encoder.setBuffer(outputBuffer, offset: 0, index: 0)
                encoder.setBytes(&localIterations, length: MemoryLayout<UInt32>.stride, index: 1)

                let width = min(max(1, pipeline.maxTotalThreadsPerThreadgroup), 256)
                let threadsPerThreadgroup = MTLSize(width: width, height: 1, depth: 1)
                let threadsPerGrid = MTLSize(width: workItems, height: 1, depth: 1)
                encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                encoder.endEncoding()
                commandBuffer.commit()
                pending.append(commandBuffer)

                if pending.count >= maxInFlight {
                    let completed = pending.removeFirst()
                    completed.waitUntilCompleted()
                    if completed.status == .error {
                        return completed.error?.localizedDescription
                            ?? "Metal 压力命令执行失败"
                    }
                }
                return nil
            }
            if let failure { return failure }
            await Task.yield()
        }

        drain(commandBuffers: pending)
        return nil
    }

    private func drain(commandBuffers: [MTLCommandBuffer]) {
        for commandBuffer in commandBuffers {
            commandBuffer.waitUntilCompleted()
        }
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void stress_kernel(device float4 *out [[buffer(0)]],
                              constant uint &iterations [[buffer(1)]],
                              uint id [[thread_position_in_grid]]) {
        float4 x = float4(float(id & 1023u) * 0.001f + 1.0f,
                          float((id >> 10u) & 1023u) * 0.001f + 2.0f,
                          float((id >> 20u) & 1023u) * 0.001f + 3.0f,
                          4.0f);

        for (uint i = 0; i < iterations; i++) {
            x = sin(x) * cos(x + 0.37f) + sqrt(abs(x) + 1.0f);
        }

        out[id] = x;
    }
    """
}

enum StressError: LocalizedError {
    case cpuUnavailable(String)
    case gpuUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .cpuUnavailable(let message):
            return message
        case .gpuUnavailable(let message):
            return message
        }
    }
}
