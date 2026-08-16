/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "AppleEventBeat.h"

#import <QuartzCore/QuartzCore.h>
#import <React/RCTUtils.h>

#include <react/debug/react_native_assert.h>

/*
 * A zero-sized layer whose only purpose is to run a callback during the
 * display phase of a Core Animation commit. Core Animation processes a commit
 * as layout → display → (repeat until stable) → commit, so a layer marked as
 * needing display during the layout phase has its `display` called after the
 * whole layout pass but before the transaction is committed.
 */
@interface RCTEventBeatFlusherLayer : CALayer
@property (nonatomic, copy, nullable) void (^onDisplay)(void);
@end

@implementation RCTEventBeatFlusherLayer

- (void)display
{
  if (self.onDisplay != nil) {
    self.onDisplay();
  }
}

// The layer is not a visual element; never participate in animations.
- (id<CAAction>)actionForKey:(NSString *)event
{
  return nil;
}

@end

namespace facebook::react {

/*
 * Owns the flusher layer and keeps it attached to the key window's layer so
 * it participates in the current Core Animation commit cycle.
 */
class AppleEventBeat::DisplayPhaseFlusher {
 public:
  DisplayPhaseFlusher(std::function<void()> callback, std::weak_ptr<const void> weakOwner)
  {
    layer_ = [RCTEventBeatFlusherLayer new];
    layer_.frame = CGRectZero;
    auto sharedCallback = std::make_shared<std::function<void()>>(std::move(callback));
    layer_.onDisplay = ^{
      // The owner (indirectly) retains the event beat; if it is gone, so is
      // the beat the callback points into.
      auto owner = weakOwner.lock();
      if (!owner) {
        return;
      }
      (*sharedCallback)();
    };
  }

  ~DisplayPhaseFlusher()
  {
    // The beat can be destroyed on any thread; layer mutations belong on the
    // main thread. The block only retains the layer, and a display happening
    // before this executes is made safe by the owner check above.
    RCTEventBeatFlusherLayer *layer = layer_;
    RCTExecuteOnMainQueue(^{
      layer.onDisplay = nil;
      [layer removeFromSuperlayer];
    });
  }

  /*
   * Schedules the callback to run in the display phase of the current (or
   * next) Core Animation commit cycle. Main thread only.
   */
  void schedule() const
  {
    CALayer *hostLayer = RCTKeyWindow().layer;
    if (hostLayer == nil) {
      // No window to participate in a commit with; the run loop observer will
      // process the request on the next turn instead.
      return;
    }
    if (layer_.superlayer != hostLayer) {
      [layer_ removeFromSuperlayer];
      [hostLayer addSublayer:layer_];
    }
    [layer_ setNeedsDisplay];
  }

 private:
  RCTEventBeatFlusherLayer *layer_;
};

AppleEventBeat::AppleEventBeat(
    std::shared_ptr<OwnerBox> ownerBox,
    std::unique_ptr<const RunLoopObserver> uiRunLoopObserver,
    RuntimeScheduler& runtimeScheduler)
    : EventBeat(std::move(ownerBox), runtimeScheduler),
      uiRunLoopObserver_(std::move(uiRunLoopObserver)),
      displayPhaseFlusher_(
          std::make_unique<DisplayPhaseFlusher>([this]() { induce(); }, ownerBox_->owner))
{
  uiRunLoopObserver_->setDelegate(this);
  uiRunLoopObserver_->enable();
}

AppleEventBeat::~AppleEventBeat() = default;

void AppleEventBeat::requestSynchronous() const
{
  EventBeat::requestSynchronous();

  // The run loop observer that ordinarily induces the beat runs before Core
  // Animation commits the frame. A synchronous request made while Core
  // Animation is already laying out (e.g. an event emitted from
  // `layoutSubviews`) would therefore only be processed on the next frame.
  // Scheduling an induce in the display phase of the current commit cycle
  // processes it before this frame is presented. Multiple requests within one
  // cycle coalesce into a single induce.
  if (RCTIsMainQueue()) {
    displayPhaseFlusher_->schedule();
  }
}

void AppleEventBeat::activityDidChange(
    const RunLoopObserver::Delegate* delegate,
    RunLoopObserver::Activity /*activity*/) const noexcept
{
  react_native_assert(delegate == this);
  induce();
}

} // namespace facebook::react
