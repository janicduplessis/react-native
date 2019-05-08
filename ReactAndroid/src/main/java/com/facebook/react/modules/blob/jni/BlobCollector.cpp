// Copyright 2004-present Facebook. All Rights Reserved.
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

#include "BlobCollector.h"

#include <fb/fbjni.h>
#include <memory>
#include <mutex>

using namespace facebook;

namespace facebook {
namespace react {

static constexpr auto kBlobModuleJavaDescriptor =
    "com/facebook/react/modules/blob/BlobModule";

BlobCollector::BlobCollector(
    jni::global_ref<jobject> blobModule,
    const std::string &blobId)
    : blobModule_(blobModule), blobId_(blobId) {}

BlobCollector::~BlobCollector() {
  auto removeMethod = jni::findClassStatic(kBlobModuleJavaDescriptor)
                          ->getMethod<void(jstring)>("remove");
  removeMethod(blobModule_, jni::make_jstring(blobId_).get());
}

void BlobCollector::nativeInstall(
    jni::alias_ref<jhybridobject> jThis,
    jni::alias_ref<jobject> blobModule,
    jlong jsContextNativePointer) {
  auto &runtime = *((jsi::Runtime *)jsContextNativePointer);
  auto blobModuleRef = jni::make_global(blobModule);
  runtime.global().setProperty(
      runtime,
      "__blobCollectorProvider",
      jsi::Function::createFromHostFunction(
          runtime,
          jsi::PropNameID::forAscii(runtime, "__blobCollectorProvider"),
          1,
          [blobModuleRef](
              jsi::Runtime &rt,
              const jsi::Value &thisVal,
              const jsi::Value *args,
              size_t count) {
            auto blobId = args[0].asString(rt).utf8(rt);
            auto blobCollector =
                std::make_shared<BlobCollector>(blobModuleRef, blobId);
            return jsi::Object::createFromHostObject(rt, blobCollector);
          }));
}

void BlobCollector::registerNatives() {
  registerHybrid(
      {makeNativeMethod("nativeInstall", BlobCollector::nativeInstall)});
}

} // namespace react
} // namespace facebook
