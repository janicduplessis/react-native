/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include <gtest/gtest.h>
#include <hermes/hermes.h>
#include <react/featureflags/ReactNativeFeatureFlags.h>
#include <react/featureflags/ReactNativeFeatureFlagsDefaults.h>
#include <react/renderer/core/EventBeat.h>
#include <react/renderer/runtimescheduler/RuntimeScheduler.h>
#include <memory>
#include <thread>

#include "StubQueue.h"

namespace facebook::react {

class EventBeatTestFeatureFlags : public ReactNativeFeatureFlagsDefaults {
 public:
  bool enableBridgelessArchitecture() override {
    return true;
  }
};

class EventBeatTest : public testing::Test {
 protected:
  void SetUp() override {
    ReactNativeFeatureFlags::dangerouslyReset();
    ReactNativeFeatureFlags::override(
        std::make_unique<EventBeatTestFeatureFlags>());

    runtime_ = facebook::hermes::makeHermesRuntime(
        ::hermes::vm::RuntimeConfig::Builder().build());
    stubQueue_ = std::make_unique<StubQueue>();

    RuntimeExecutor runtimeExecutor =
        [this](
            std::function<void(facebook::jsi::Runtime & runtime)>&& callback) {
          stubQueue_->runOnQueue([this, callback = std::move(callback)]() {
            callback(*runtime_);
          });
        };

    runtimeScheduler_ = std::make_unique<RuntimeScheduler>(runtimeExecutor);

    ownerBox_ = std::make_shared<EventBeat::OwnerBox>();
    owner_ = std::make_shared<int>(0);
    ownerBox_->owner = owner_;
    eventBeat_ = std::make_unique<EventBeat>(ownerBox_, *runtimeScheduler_);
  }

  void TearDown() override {
    ReactNativeFeatureFlags::dangerouslyReset();
  }

  /*
   * Drives the stub queue ("JS thread") from a separate thread so that
   * `executeNowOnTheSameThread` performed by the beat can complete.
   */
  void tickOnDriverThread() {
    std::thread driver([this]() {
      stubQueue_->waitForTask();
      stubQueue_->tick();
    });
    driver.join();
  }

  std::unique_ptr<facebook::hermes::HermesRuntime> runtime_;
  std::unique_ptr<StubQueue> stubQueue_;
  std::unique_ptr<RuntimeScheduler> runtimeScheduler_;
  std::shared_ptr<EventBeat::OwnerBox> ownerBox_;
  std::shared_ptr<int> owner_;
  std::unique_ptr<EventBeat> eventBeat_;
};

TEST_F(EventBeatTest, induceWithoutRequestIsNoop) {
  int beatCount = 0;
  eventBeat_->setBeatCallback([&beatCount](jsi::Runtime& /*runtime*/) {
    beatCount++;
  });

  eventBeat_->induce();

  EXPECT_EQ(beatCount, 0);
  EXPECT_EQ(stubQueue_->size(), 0);
}

TEST_F(EventBeatTest, synchronousRequestIsProcessedAtInduce) {
  int beatCount = 0;
  eventBeat_->setBeatCallback([&beatCount](jsi::Runtime& /*runtime*/) {
    beatCount++;
  });

  eventBeat_->requestSynchronous();
  EXPECT_EQ(beatCount, 0);

  // A consumer that wants the beat processed at the call site (see
  // `EventQueue::experimental_flushSync` with `immediate`) calls `induce`
  // right after requesting. The beat callback runs synchronously before
  // `induce` returns, with both threads blocked.
  std::thread driver([this]() {
    stubQueue_->waitForTask();
    stubQueue_->tick();
  });
  eventBeat_->induce();
  driver.join();

  EXPECT_EQ(beatCount, 1);

  // The request was consumed: another induce does nothing.
  eventBeat_->induce();
  EXPECT_EQ(beatCount, 1);
  EXPECT_EQ(stubQueue_->size(), 0);
}

TEST_F(EventBeatTest, nestedInduceDuringBeatDoesNotReenter) {
  int beatCount = 0;
  eventBeat_->setBeatCallback([&](jsi::Runtime& /*runtime*/) {
    beatCount++;
    if (beatCount == 1) {
      // An event dispatched from within the beat (e.g. a synchronous event
      // whose handler causes another synchronous event) must not re-enter the
      // beat callback.
      eventBeat_->requestSynchronous();
      eventBeat_->induce();
    }
  });

  eventBeat_->requestSynchronous();
  std::thread driver([this]() {
    stubQueue_->waitForTask();
    stubQueue_->tick();
  });
  eventBeat_->induce();
  driver.join();

  EXPECT_EQ(beatCount, 1);

  // The nested beat is processed on a subsequent request + induce instead.
  eventBeat_->requestSynchronous();
  std::thread driver2([this]() {
    stubQueue_->waitForTask();
    stubQueue_->tick();
  });
  eventBeat_->induce();
  driver2.join();

  EXPECT_EQ(beatCount, 2);
}

} // namespace facebook::react
