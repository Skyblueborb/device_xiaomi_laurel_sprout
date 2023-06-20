## ih8sn
PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/bin/ih8sn \
    system/etc/ih8sn.conf \
    system/etc/init/ih8sn.rc

PRODUCT_PACKAGES += ih8sn

PRODUCT_CONFIGURATION_FILE := ih8sn.conf.$(shell echo $(TARGET_PRODUCT) | cut -d'_' -f2-)

ifneq ("$(wildcard ih8sn/system/etc/$(PRODUCT_CONFIGURATION_FILE))","")
PRODUCT_COPY_FILES += \
    ih8sn/system/etc/$(PRODUCT_CONFIGURATION_FILE):$(TARGET_COPY_OUT_SYSTEM)/etc/ih8sn.conf
else
PRODUCT_COPY_FILES += \
    ih8sn/system/etc/ih8sn.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/ih8sn.conf
endif
