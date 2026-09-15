/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

#include <functional>
#include <memory>
#include <optional>

#import <QuartzCore/QuartzCore.h>

#include <ReactCommon/RuntimeExecutor.h>
#include <react/renderer/core/EventBeat.h>
#include <react/utils/RunLoopObserver.h>

namespace facebook::react {

class RuntimeScheduler;

/*
 * Event beat associated with JavaScript runtime.
 * The beat is called on `RuntimeExecutor`'s thread induced by the UI thread
 * event loop.
 *
 * A synchronous request made while Core Animation is laying out the current
 * frame (the run loop observer that induces the beat has already run at that
 * point) is additionally induced from the display phase of the same commit
 * cycle, so that its effects are mounted before the frame is presented. The
 * induce is scheduled on the layer of the requesting view's window — the root
 * of the tree Core Animation is laying out when the request is made from
 * layout, including for content mounted in another window (a full screen
 * modal, LogBox).
 */
class AppleEventBeat : public EventBeat, public RunLoopObserver::Delegate {
 public:
  /*
   * Resolves the layer of the window containing the view with the given tag.
   * Called on the main thread; returns nil when the view is not mounted or
   * not attached to a window. Must not create views.
   */
  using WindowLayerResolver = std::function<CALayer *(Tag)>;

  AppleEventBeat(
      std::shared_ptr<OwnerBox> ownerBox,
      std::unique_ptr<const RunLoopObserver> uiRunLoopObserver,
      RuntimeScheduler &RuntimeScheduler,
      WindowLayerResolver windowLayerResolver);

  ~AppleEventBeat() override;

  using EventBeat::requestSynchronous;
  void requestSynchronous(std::optional<Tag> tag) const override;

#pragma mark - RunLoopObserver::Delegate

  void activityDidChange(const RunLoopObserver::Delegate *delegate, RunLoopObserver::Activity activity)
      const noexcept override;

 private:
  class DisplayPhaseFlusher;

  std::unique_ptr<const RunLoopObserver> uiRunLoopObserver_;
  std::unique_ptr<DisplayPhaseFlusher> displayPhaseFlusher_;
};

} // namespace facebook::react
