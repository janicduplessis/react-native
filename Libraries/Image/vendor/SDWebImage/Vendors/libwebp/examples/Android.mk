LOCAL_PATH := $(call my-dir)

################################################################################
# libexample_util

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    example_util.c \

LOCAL_CFLAGS := $(WEBP_CFLAGS)
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../src

LOCAL_MODULE := example_util

include $(BUILD_STATIC_LIBRARY)


################################################################################
# libexample_dec

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    image_dec.c \
    jpegdec.c \
    metadata.c \
    pngdec.c \
    tiffdec.c \
    webpdec.c \

LOCAL_CFLAGS := $(WEBP_CFLAGS)
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../src

LOCAL_MODULE := example_dec

include $(BUILD_STATIC_LIBRARY)

################################################################################
# cwebp

include $(CLEAR_VARS)

# Note: to enable jpeg/png encoding the sources from AOSP can be used with
# minor modification to their Android.mk files.
LOCAL_SRC_FILES := \
    cwebp.c \

LOCAL_CFLAGS := $(WEBP_CFLAGS)
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../src
LOCAL_STATIC_LIBRARIES := example_util example_dec webp

LOCAL_MODULE := cwebp

include $(BUILD_EXECUTABLE)

################################################################################
# dwebp

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    dwebp.c \

LOCAL_CFLAGS := $(WEBP_CFLAGS)
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../src
LOCAL_STATIC_LIBRARIES := example_util webp

LOCAL_MODULE := dwebp

include $(BUILD_EXECUTABLE)

################################################################################
# webpmux

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    webpmux.c \

LOCAL_CFLAGS := $(WEBP_CFLAGS)
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../src
LOCAL_STATIC_LIBRARIES := example_util webpmux webp

LOCAL_MODULE := webpmux_example

include $(BUILD_EXECUTABLE)
