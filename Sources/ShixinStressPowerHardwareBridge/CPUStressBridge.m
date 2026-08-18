// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ShixinStressPowerHardwareBridge.h"

#import <math.h>
#import <pthread.h>
#import <stdint.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <stdlib.h>
#import <string.h>
#import <sched.h>

#if defined(__APPLE__)
#import <pthread/qos.h>
#endif

#if defined(__arm64__) || defined(__aarch64__)
#import <arm_neon.h>
#endif

struct ShixinCPUStressRun {
    atomic_bool cancelled;
    int32_t workerCount;
    pthread_t *threads;
};

typedef struct {
    ShixinCPUStressRun *run;
    int32_t workerID;
} ShixinCPUStressWorkerContext;

static atomic_uint_fast64_t ShixinCPUStressSink = 0;

static inline uint64_t ShixinStressMixBits(float value, int32_t workerID) {
    uint32_t bits = 0;
    memcpy(&bits, &value, sizeof(bits));
    return ((uint64_t)bits << 32) ^ (uint64_t)(uint32_t)workerID;
}

#if defined(__arm64__) || defined(__aarch64__)
static inline float ShixinReduceFloat32x4(float32x4_t value) {
    return vgetq_lane_f32(value, 0)
        + vgetq_lane_f32(value, 1)
        + vgetq_lane_f32(value, 2)
        + vgetq_lane_f32(value, 3);
}

static inline float32x4_t ShixinSeedVector(float base) {
    return (float32x4_t){base, base + 0.013f, base + 0.027f, base + 0.041f};
}

static inline double ShixinReduceFloat64x2(float64x2_t value) {
    return vgetq_lane_f64(value, 0) + vgetq_lane_f64(value, 1);
}

static inline float64x2_t ShixinSeedVector64(double base) {
    return (float64x2_t){base, base + 0.000013};
}

static void ShixinCPUStressRunARM(ShixinCPUStressRun *run, int32_t workerID) {
    const float seed = 0.03125f * (float)(workerID + 1);
    const float32x4_t decay0 = vdupq_n_f32(0.999931f);
    const float32x4_t decay1 = vdupq_n_f32(0.999923f);
    const float32x4_t k0 = vdupq_n_f32(0.000137f);
    const float32x4_t k1 = vdupq_n_f32(0.000173f);
    const float32x4_t k2 = vdupq_n_f32(0.000211f);
    const float32x4_t k3 = vdupq_n_f32(0.000257f);

    float32x4_t a0 = ShixinSeedVector(seed + 0.10f);
    float32x4_t a1 = ShixinSeedVector(seed + 0.31f);
    float32x4_t a2 = ShixinSeedVector(seed + 0.53f);
    float32x4_t a3 = ShixinSeedVector(seed + 0.79f);
    float32x4_t a4 = ShixinSeedVector(seed + 1.01f);
    float32x4_t a5 = ShixinSeedVector(seed + 1.23f);
    float32x4_t a6 = ShixinSeedVector(seed + 1.47f);
    float32x4_t a7 = ShixinSeedVector(seed + 1.71f);
    const double seed64 = 0.0003125 * (double)(workerID + 1);
    const float64x2_t dDecay0 = vdupq_n_f64(0.9999991);
    const float64x2_t dDecay1 = vdupq_n_f64(0.9999989);
    const float64x2_t dk0 = vdupq_n_f64(0.00000137);
    const float64x2_t dk1 = vdupq_n_f64(0.00000173);
    const float64x2_t dk2 = vdupq_n_f64(0.00000211);
    const float64x2_t dk3 = vdupq_n_f64(0.00000257);
    float64x2_t d0 = ShixinSeedVector64(seed64 + 0.0010);
    float64x2_t d1 = ShixinSeedVector64(seed64 + 0.0031);
    float64x2_t d2 = ShixinSeedVector64(seed64 + 0.0053);
    float64x2_t d3 = ShixinSeedVector64(seed64 + 0.0079);
    float64x2_t d4 = ShixinSeedVector64(seed64 + 0.0101);
    float64x2_t d5 = ShixinSeedVector64(seed64 + 0.0123);
    float64x2_t d6 = ShixinSeedVector64(seed64 + 0.0147);
    float64x2_t d7 = ShixinSeedVector64(seed64 + 0.0171);
    uint64_t localSink = (uint64_t)(workerID + 1);

    while (!atomic_load_explicit(&run->cancelled, memory_order_relaxed)) {
        for (int i = 0; i < 65536; i++) {
            a0 = vfmaq_f32(vmulq_f32(a0, decay0), a1, k0);
            a1 = vfmaq_f32(vmulq_f32(a1, decay1), a2, k1);
            a2 = vfmaq_f32(vmulq_f32(a2, decay0), a3, k2);
            a3 = vfmaq_f32(vmulq_f32(a3, decay1), a0, k3);
            a4 = vfmaq_f32(vmulq_f32(a4, decay0), a5, k3);
            a5 = vfmaq_f32(vmulq_f32(a5, decay1), a6, k2);
            a6 = vfmaq_f32(vmulq_f32(a6, decay0), a7, k1);
            a7 = vfmaq_f32(vmulq_f32(a7, decay1), a4, k0);
            d0 = vfmaq_f64(vmulq_f64(d0, dDecay0), d1, dk0);
            d1 = vfmaq_f64(vmulq_f64(d1, dDecay1), d2, dk1);
            d2 = vfmaq_f64(vmulq_f64(d2, dDecay0), d3, dk2);
            d3 = vfmaq_f64(vmulq_f64(d3, dDecay1), d0, dk3);
            d4 = vfmaq_f64(vmulq_f64(d4, dDecay0), d5, dk3);
            d5 = vfmaq_f64(vmulq_f64(d5, dDecay1), d6, dk2);
            d6 = vfmaq_f64(vmulq_f64(d6, dDecay0), d7, dk1);
            d7 = vfmaq_f64(vmulq_f64(d7, dDecay1), d4, dk0);
        }

        float sum = ShixinReduceFloat32x4(a0)
            + ShixinReduceFloat32x4(a1)
            + ShixinReduceFloat32x4(a2)
            + ShixinReduceFloat32x4(a3)
            + ShixinReduceFloat32x4(a4)
            + ShixinReduceFloat32x4(a5)
            + ShixinReduceFloat32x4(a6)
            + ShixinReduceFloat32x4(a7);
        double sum64 = ShixinReduceFloat64x2(d0)
            + ShixinReduceFloat64x2(d1)
            + ShixinReduceFloat64x2(d2)
            + ShixinReduceFloat64x2(d3)
            + ShixinReduceFloat64x2(d4)
            + ShixinReduceFloat64x2(d5)
            + ShixinReduceFloat64x2(d6)
            + ShixinReduceFloat64x2(d7);

        if (!isfinite(sum) || fabsf(sum) > 100000.0f || !isfinite(sum64) || fabs(sum64) > 100000.0) {
            a0 = ShixinSeedVector(seed + 0.10f);
            a1 = ShixinSeedVector(seed + 0.31f);
            a2 = ShixinSeedVector(seed + 0.53f);
            a3 = ShixinSeedVector(seed + 0.79f);
            a4 = ShixinSeedVector(seed + 1.01f);
            a5 = ShixinSeedVector(seed + 1.23f);
            a6 = ShixinSeedVector(seed + 1.47f);
            a7 = ShixinSeedVector(seed + 1.71f);
            d0 = ShixinSeedVector64(seed64 + 0.0010);
            d1 = ShixinSeedVector64(seed64 + 0.0031);
            d2 = ShixinSeedVector64(seed64 + 0.0053);
            d3 = ShixinSeedVector64(seed64 + 0.0079);
            d4 = ShixinSeedVector64(seed64 + 0.0101);
            d5 = ShixinSeedVector64(seed64 + 0.0123);
            d6 = ShixinSeedVector64(seed64 + 0.0147);
            d7 = ShixinSeedVector64(seed64 + 0.0171);
            sum = seed;
            sum64 = seed64;
        }

        localSink ^= ShixinStressMixBits(sum + (float)sum64, workerID);
        atomic_fetch_xor_explicit(&ShixinCPUStressSink, localSink, memory_order_relaxed);
        sched_yield();
    }
}
#endif

static void ShixinCPUStressRunScalar(ShixinCPUStressRun *run, int32_t workerID) {
    double a = 0.013 * (double)(workerID + 1);
    double b = 0.071 + a;
    double c = 0.193 + a;
    uint64_t localSink = (uint64_t)(workerID + 1);

    while (!atomic_load_explicit(&run->cancelled, memory_order_relaxed)) {
        for (int i = 0; i < 65536; i++) {
            a = fma(a, 0.999991, b * 0.000019) + 0.000003;
            b = fma(b, 0.999989, c * 0.000023) + 0.000005;
            c = fma(c, 0.999987, a * 0.000029) + 0.000007;
        }
        double sum = a + b + c;
        if (!isfinite(sum) || fabs(sum) > 100000.0) {
            a = 0.013 * (double)(workerID + 1);
            b = 0.071 + a;
            c = 0.193 + a;
            sum = a + b + c;
        }
        localSink ^= ShixinStressMixBits((float)sum, workerID);
        atomic_fetch_xor_explicit(&ShixinCPUStressSink, localSink, memory_order_relaxed);
        sched_yield();
    }
}

static void *ShixinCPUStressWorkerMain(void *rawContext) {
    ShixinCPUStressWorkerContext *context = (ShixinCPUStressWorkerContext *)rawContext;
    ShixinCPUStressRun *run = context->run;
    int32_t workerID = context->workerID;
    free(context);

#if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, 0);
#endif

#if defined(__arm64__) || defined(__aarch64__)
    ShixinCPUStressRunARM(run, workerID);
#else
    ShixinCPUStressRunScalar(run, workerID);
#endif
    return NULL;
}

ShixinCPUStressRun *ShixinCPUStressRunCreate(int32_t workerCount) {
    if (workerCount < 1) {
        workerCount = 1;
    }
    if (workerCount > 128) {
        workerCount = 128;
    }

    ShixinCPUStressRun *run = calloc(1, sizeof(ShixinCPUStressRun));
    if (run == NULL) {
        return NULL;
    }

    run->workerCount = workerCount;
    run->threads = calloc((size_t)workerCount, sizeof(pthread_t));
    if (run->threads == NULL) {
        free(run);
        return NULL;
    }
    atomic_init(&run->cancelled, false);

    int32_t started = 0;
    for (int32_t index = 0; index < workerCount; index++) {
        ShixinCPUStressWorkerContext *context = malloc(sizeof(ShixinCPUStressWorkerContext));
        if (context == NULL) {
            break;
        }
        context->run = run;
        context->workerID = index;
        if (pthread_create(&run->threads[index], NULL, ShixinCPUStressWorkerMain, context) != 0) {
            free(context);
            break;
        }
        started++;
    }

    if (started == 0) {
        free(run->threads);
        free(run);
        return NULL;
    }
    run->workerCount = started;
    return run;
}

int32_t ShixinCPUStressRunGetWorkerCount(const ShixinCPUStressRun *run) {
    return run == NULL ? 0 : run->workerCount;
}

void ShixinCPUStressRunStop(ShixinCPUStressRun *run) {
    if (run == NULL) {
        return;
    }

    atomic_store_explicit(&run->cancelled, true, memory_order_relaxed);
    for (int32_t index = 0; index < run->workerCount; index++) {
        pthread_join(run->threads[index], NULL);
    }
    free(run->threads);
    free(run);
}
