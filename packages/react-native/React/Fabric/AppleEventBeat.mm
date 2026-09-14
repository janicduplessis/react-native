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
 * Owns the flusher layers, one per surface that has made a synchronous
 * request, attached to the layer of that surface's root view. A request made
 * from layout runs inside the commit of exactly that tree, so its layer is
 * guaranteed a display phase in the current cycle — no assumption about
 * which window is key or about all windows committing together.
 */
class AppleEventBeat::DisplayPhaseFlusher {
 public:
  DisplayPhaseFlusher(
      std::function<void()> callback,
      std::weak_ptr<const void> weakOwner,
      SurfaceLayerResolver surfaceLayerResolver)
      : surfaceLayerResolver_(std::move(surfaceLayerResolver))
  {
    // Weak keys: a root view that goes away takes its own flusher layer with
    // it.
    layers_ = [NSMapTable weakToStrongObjectsMapTable];
    auto sharedCallback = std::make_shared<std::function<void()>>(std::move(callback));
    onDisplay_ = ^{
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
    // main thread. The block only retains the layers, and a display happening
    // before this executes is made safe by the owner check above.
    NSMapTable<CALayer *, RCTEventBeatFlusherLayer *> *layers = layers_;
    RCTExecuteOnMainQueue(^{
      for (RCTEventBeatFlusherLayer *layer in layers.objectEnumerator) {
        layer.onDisplay = nil;
        [layer removeFromSuperlayer];
      }
      [layers removeAllObjects];
    });
  }

  /*
   * Schedules the callback to run in the display phase of the current (or
   * next) Core Animation commit cycle, on the layer tree of the surface's
   * root view. Main thread only. Does nothing when the surface has no mounted
   * view; the run loop observer then processes the request on its ordinary
   * schedule instead.
   */
  void schedule(SurfaceId surfaceId) const
  {
    CALayer *hostLayer = surfaceLayerResolver_ ? surfaceLayerResolver_(surfaceId) : nil;
    if (hostLayer == nil) {
      return;
    }
    RCTEventBeatFlusherLayer *layer = [layers_ objectForKey:hostLayer];
    if (layer == nil) {
      layer = [RCTEventBeatFlusherLayer new];
      layer.frame = CGRectZero;
      layer.onDisplay = onDisplay_;
      [layers_ setObject:layer forKey:hostLayer];
    }
    if (layer.superlayer != hostLayer) {
      [layer removeFromSuperlayer];
      [hostLayer addSublayer:layer];
    }
    [layer setNeedsDisplay];
  }

 private:
  SurfaceLayerResolver surfaceLayerResolver_;
  NSMapTable<CALayer *, RCTEventBeatFlusherLayer *> *layers_;
  void (^onDisplay_)(void);
};

AppleEventBeat::AppleEventBeat(std::shared_ptr<OwnerBox> ownerBox,
                               std::unique_ptr<const RunLoopObserver> uiRunLoopObserver,
                               RuntimeScheduler &runtimeScheduler,
                               SurfaceLayerResolver surfaceLayerResolver)
    : EventBeat(std::move(ownerBox), runtimeScheduler),
      uiRunLoopObserver_(std::move(uiRunLoopObserver)),
      displayPhaseFlusher_(std::make_unique<DisplayPhaseFlusher>(
          [this]() { induce(); },
          ownerBox_->owner,
          std::move(surfaceLayerResolver)))
{
  uiRunLoopObserver_->setDelegate(this);
  uiRunLoopObserver_->enable();
}

AppleEventBeat::~AppleEventBeat() = default;

void AppleEventBeat::requestSynchronous(std::optional<SurfaceId> surfaceId) const
{
  EventBeat::requestSynchronous(surfaceId);

  // The run loop observer that ordinarily induces the beat runs before Core
  // Animation commits the frame. A synchronous request made while Core
  // Animation is already laying out (e.g. an event emitted from
  // `layoutSubviews`) would therefore only be processed on the next frame.
  // Scheduling an induce in the display phase of the current commit cycle
  // processes it before this frame is presented. Multiple requests within one
  // cycle coalesce into a single induce.
  if (surfaceId.has_value() && RCTIsMainQueue()) {
    displayPhaseFlusher_->schedule(*surfaceId);
  }
}

void AppleEventBeat::activityDidChange(const RunLoopObserver::Delegate *delegate,
                                       RunLoopObserver::Activity /*activity*/) const noexcept
{
  react_native_assert(delegate == this);
  induce();
}

} // namespace facebook::react
