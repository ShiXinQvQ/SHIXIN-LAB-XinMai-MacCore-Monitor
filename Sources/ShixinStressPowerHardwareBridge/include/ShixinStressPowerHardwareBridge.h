// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary<NSString *, NSNumber *> *ShixinAppleSiliconTemperatureSensors(void);

typedef struct ShixinCPUStressRun ShixinCPUStressRun;

ShixinCPUStressRun *_Nullable ShixinCPUStressRunCreate(int32_t workerCount);
int32_t ShixinCPUStressRunGetWorkerCount(const ShixinCPUStressRun *_Nullable run);
void ShixinCPUStressRunStop(ShixinCPUStressRun *_Nullable run);

NS_ASSUME_NONNULL_END
