/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTBlobCollector.h"

#import <React/RCTBridge+Private.h>
#import "RCTBlobManager.h"

namespace facebook {
namespace react {

RCTBlobCollector::RCTBlobCollector(RCTBlobManager *blobManager, const std::string &blobId)
: blobId_(blobId), blobManager_(blobManager) {}

RCTBlobCollector::~RCTBlobCollector() {
  RCTBlobManager *blobManager = blobManager_;
  NSString *blobId = [NSString stringWithUTF8String:blobId_.c_str()];
  dispatch_async([blobManager_ methodQueue], ^{
    [blobManager remove:blobId];
  });
}

void RCTBlobCollector::install(RCTBlobManager *blobManager) {
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)blobManager.bridge;
  if (cxxBridge.runtime == nullptr) {
    return;
  }
  [cxxBridge dispatchBlock:^{
    jsi::Runtime &runtime = *(jsi::Runtime *)cxxBridge.runtime;
    runtime.global().setProperty(
      runtime,
      "__blobCollectorProvider",
      jsi::Function::createFromHostFunction(
        runtime,
        jsi::PropNameID::forAscii(runtime, "__blobCollectorProvider"),
        1,
        [blobManager](jsi::Runtime& rt, const jsi::Value& thisVal, const jsi::Value* args, size_t count) {
          auto blobId = args[0].asString(rt).utf8(rt);
          auto blobCollector = std::make_shared<RCTBlobCollector>(blobManager, blobId);
          return jsi::Object::createFromHostObject(rt, blobCollector);
        }
      )
    );
  } queue:RCTJSThread];
}

} // namespace react
} // namespace facebook
