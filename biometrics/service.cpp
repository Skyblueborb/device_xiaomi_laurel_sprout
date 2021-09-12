/*
 * Copyright (C) 2019 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "android.hardware.biometrics.fingerprint@2.3-service.laurel_sprout"

#include <android-base/logging.h>
#include <hidl/HidlTransportSupport.h>

#include "BiometricsFingerprint.h"

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;

using android::hardware::biometrics::fingerprint::V2_3::IBiometricsFingerprint;
using android::hardware::biometrics::fingerprint::V2_3::implementation::BiometricsFingerprint;

using android::OK;
using android::status_t;

int main() {
    android::sp<IBiometricsFingerprint> service = new BiometricsFingerprint();

    configureRpcThreadpool(1, true);

    status_t status = service->registerAsService();
    if (status != OK) {
        LOG(ERROR) << "Cannot register Biometrics 2.3 HAL service.";
        return 1;
    }

    LOG(INFO) << "Biometrics 2.3 HAL service ready.";

    joinRpcThreadpool();

    LOG(ERROR) << "Biometrics 2.3 HAL service failed to join thread pool.";
    return 1;
}
