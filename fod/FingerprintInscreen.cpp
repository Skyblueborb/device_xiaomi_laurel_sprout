/*
 * Copyright (C) 2019 The LineageOS Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "FingerprintInscreenService"

#include "FingerprintInscreen.h"

#include <android-base/logging.h>
#include <fstream>
#include <cmath>
#include <thread>

#define FINGERPRINT_ERROR_VENDOR 8

#define COMMAND_NIT 10
#define PARAM_NIT_FOD 3
#define PARAM_NIT_NONE 0

#define DISPPARAM_PATH "/sys/devices/platform/soc/5e00000.qcom,mdss_mdp/drm/card0/card0-DSI-1/disp_param"
#define DISPPARAM_HBM_FOD_ON "0x1D20000"
#define DISPPARAM_HBM_FOD_OFF "0x20F0000"

#define FOD_STATUS_PATH "/sys/class/touch/tp_dev/fod_status"
#define FOD_STATUS_ON 1
#define FOD_STATUS_OFF 0

#define FOD_SENSOR_X 293
#define FOD_SENSOR_Y 1356
#define FOD_SENSOR_SIZE 134

namespace {

template <typename T>
static void set(const std::string& path, const T& value) {
    std::ofstream file(path);
    file << value;
}

} // anonymous namespace

namespace vendor {
namespace lineage {
namespace biometrics {
namespace fingerprint {
namespace inscreen {
namespace V1_0 {
namespace implementation {

FingerprintInscreen::FingerprintInscreen() {
    xiaomiFingerprintService = IXiaomiFingerprint::getService();
}

Return<int32_t> FingerprintInscreen::getPositionX() {
    return FOD_SENSOR_X;
}

Return<int32_t> FingerprintInscreen::getPositionY() {
    return FOD_SENSOR_Y;
}

Return<int32_t> FingerprintInscreen::getSize() {
    return FOD_SENSOR_SIZE;
}

Return<void> FingerprintInscreen::onStartEnroll() {
    return Void();
}

Return<void> FingerprintInscreen::onFinishEnroll() {
    return Void();
}

Return<void> FingerprintInscreen::onPress() {
    std::thread([this]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
            set(DISPPARAM_PATH, DISPPARAM_HBM_FOD_ON);
    	    xiaomiFingerprintService->extCmd(COMMAND_NIT, PARAM_NIT_FOD);
    }).detach();
    return Void();
}

Return<void> FingerprintInscreen::onRelease() {
    set(DISPPARAM_PATH, DISPPARAM_HBM_FOD_OFF);
    xiaomiFingerprintService->extCmd(COMMAND_NIT, PARAM_NIT_NONE);
    return Void();
}

Return<void> FingerprintInscreen::onShowFODView() {
    set(FOD_STATUS_PATH, FOD_STATUS_ON);
    return Void();
}

Return<void> FingerprintInscreen::onHideFODView() {
    set(FOD_STATUS_PATH, FOD_STATUS_OFF);
    set(DISPPARAM_PATH, DISPPARAM_HBM_FOD_OFF);
    return Void();
}

Return<bool> FingerprintInscreen::handleAcquired(int32_t acquiredInfo, int32_t vendorCode) {
    LOG(ERROR) << "acquiredInfo: " << acquiredInfo << ", vendorCode: " << vendorCode << "\n";
    return false;
}

Return<bool> FingerprintInscreen::handleError(int32_t error, int32_t vendorCode) {
    LOG(ERROR) << "error: " << error << ", vendorCode: " << vendorCode << "\n";
    return error == FINGERPRINT_ERROR_VENDOR && vendorCode == 6;
}

Return<void> FingerprintInscreen::setLongPressEnabled(bool) {
    return Void();
}

Return<int32_t> FingerprintInscreen::getDimAmount(int32_t brightness) {
    if (brightness > 230) // 100-97%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.52)));
        /* return 100000; */
    else if (brightness > 160) // 97-91%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.550452)));
        /* return 100000; */
    else if (brightness > 100) // 91-83%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.5677)));
        /* return 100000; */
    else if (brightness > 50) // 83-70%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.6233)));
        /* return 100000; */
    else if (brightness > 20) // 70-49%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.66385)));
        /* return 100000; */
    else if (brightness > 10) // 49-34%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.75477)));
        /* return 100000; */
    else if (brightness > 4) // 34-21%
        return(int32_t)(255 + ((-12.08071) * pow((double)brightness, 0.905)));
        /* return 100000; */
    else if (brightness <= 4) // 21-0%
        return(int32_t)(255 + ((-12.8) * (double)brightness));
        /* return 100000; */
    else return 100000; // how tf do you even exist
}

Return<bool> FingerprintInscreen::shouldBoostBrightness() {
    return false;
}

Return<void> FingerprintInscreen::setCallback(const sp<IFingerprintInscreenCallback>& /* callback */) {
    return Void();
}

}  // namespace implementation
}  // namespace V1_0
}  // namespace inscreen
}  // namespace fingerprint
}  // namespace biometrics
}  // namespace lineage
}  // namespace vendor
