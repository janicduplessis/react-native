/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTImageResponseDelegate.h>
#import <React/RCTViewComponentView.h>
#import <SDWebImage/SDWebImage.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * UIView class for root <Image> component.
 */
@interface RCTImageComponentView : RCTViewComponentView {
 @protected
  SDAnimatedImageView *_imageView;
}

@end

NS_ASSUME_NONNULL_END
