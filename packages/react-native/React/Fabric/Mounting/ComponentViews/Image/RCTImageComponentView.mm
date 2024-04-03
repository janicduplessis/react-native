/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTImageComponentView.h"

#import <React/RCTAssert.h>
#import <React/RCTConversions.h>
#import <React/RCTImageBlurUtils.h>
#import <React/RCTImageResponseObserverProxy.h>
#import <react/renderer/components/image/ImageComponentDescriptor.h>
#import <react/renderer/components/image/ImageEventEmitter.h>
#import <react/renderer/components/image/ImageProps.h>
#import <react/renderer/imagemanager/ImageRequest.h>
#import <react/renderer/imagemanager/RCTImagePrimitivesConversions.h>
#import <react/utils/CoreFeatures.h>

#import <SDWebImageAVIFCoder/SDImageAVIFCoder.h>
#import <SDWebImagePhotosPlugin/SDWebImagePhotosPlugin.h>
#import <SDWebImageWebPCoder/SDWebImageWebPCoder.h>

using namespace facebook::react;

@implementation RCTImageComponentView {
  ImageShadowNode::ConcreteState::Shared _state;
  RCTImageResponseObserverProxy _imageResponseObserverProxy;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    const auto &defaultProps = ImageShadowNode::defaultSharedProps();
    _props = defaultProps;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      SDImageAVIFCoder *AVIFCoder = [SDImageAVIFCoder sharedCoder];
      [SDImageCodersManager.sharedManager addCoder:AVIFCoder];
      SDImageWebPCoder *webPCoder = [SDImageWebPCoder sharedCoder];
      [SDImageCodersManager.sharedManager addCoder:webPCoder];
      // Supports HTTP URL as well as Photos URL globally
      SDImageLoadersManager.sharedManager.loaders =
          @[ SDWebImageDownloader.sharedDownloader, SDImagePhotosLoader.sharedLoader ];
      // Replace default manager's loader implementation
      SDWebImageManager.defaultImageLoader = SDImageLoadersManager.sharedManager;
    });

    _imageView = [SDAnimatedImageView new];
    _imageView.clipsToBounds = YES;
    _imageView.contentMode = RCTContentModeFromImageResizeMode(defaultProps->resizeMode);
    _imageView.layer.minificationFilter = kCAFilterTrilinear;
    _imageView.layer.magnificationFilter = kCAFilterTrilinear;

    self.contentView = _imageView;
  }

  return self;
}

#pragma mark - RCTComponentViewProtocol

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<ImageComponentDescriptor>();
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &oldImageProps = static_cast<const ImageProps &>(*_props);
  const auto &newImageProps = static_cast<const ImageProps &>(*props);

  // `resizeMode`
  if (oldImageProps.resizeMode != newImageProps.resizeMode) {
    _imageView.contentMode = RCTContentModeFromImageResizeMode(newImageProps.resizeMode);
  }

  // `tintColor`
  if (oldImageProps.tintColor != newImageProps.tintColor) {
    _imageView.tintColor = RCTUIColorFromSharedColor(newImageProps.tintColor);
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)updateState:(const State::Shared &)state oldState:(const State::Shared &)oldState
{
  RCTAssert(state, @"`state` must not be null.");
  RCTAssert(
      std::dynamic_pointer_cast<ImageShadowNode::ConcreteState const>(state),
      @"`state` must be a pointer to `ImageShadowNode::ConcreteState`.");

  auto oldImageState = std::static_pointer_cast<ImageShadowNode::ConcreteState const>(_state);
  auto newImageState = std::static_pointer_cast<ImageShadowNode::ConcreteState const>(state);
  // TODO: Add fadeDuration
  // const auto &imageProps = static_cast<const ImageProps &>(*_props);

  _state = newImageState;

  bool havePreviousData = oldImageState && oldImageState->getData().getImageSource() != ImageSource{};

  if (!havePreviousData ||
      (newImageState && newImageState->getData().getImageSource() != oldImageState->getData().getImageSource())) {
    NSURL *url = [NSURL URLWithString:RCTNSStringFromString(newImageState->getData().getImageSource().uri)];

    __weak RCTImageComponentView *weakSelf = self;
    SDImageLoaderProgressBlock progressHandler =
        ^(NSInteger receivedSize, NSInteger expectedSize, NSURL *_Nullable targetURL) {
          __typeof(self) strongSelf = weakSelf;
          if (!strongSelf) {
            return;
          }

          [strongSelf didReceiveProgress:receivedSize / (float)expectedSize];
        };

    SDExternalCompletionBlock completionHandler =
        ^(UIImage *_Nullable image, NSError *_Nullable error, SDImageCacheType cacheType, NSURL *_Nullable imageURL) {
          __typeof(self) strongSelf = weakSelf;
          if (!strongSelf) {
            return;
          }

          if (error) {
            [strongSelf didReceiveFailure];
            return;
          }

          if (image && (cacheType == SDImageCacheTypeNone || cacheType == SDImageCacheTypeDisk)) {
            weakSelf.alpha = 0;
            [UIView animateWithDuration:0.3
                             animations:^{
                               weakSelf.alpha = 1;
                             }];
          }

          [strongSelf didReceiveImage:image];
        };

    // Handle asset bundle images.
    if (RCTIsBundleAssetURL(url)) {
      NSString *catalogName = RCTAssetCatalogNameForURL(url);
      if (catalogName) {
        UIImage *image = [UIImage imageNamed:catalogName];
        [_imageView sd_cancelCurrentImageLoad];
        _imageView.image = image;
        if (progressHandler) {
          progressHandler(1, 1, url);
        }
        completionHandler(image, nil, SDImageCacheTypeMemory, url);
        return;
      }
    }

    // Rewrite assets library to use the same scheme that SDWebImage expects.
    if ([url.scheme isEqualToString:@"assets-library"] || [url.scheme isEqualToString:@"ph"]) {
      url = [NSURL sd_URLWithAssetLocalIdentifier:url.path];
    }

    [_imageView sd_setImageWithURL:url
                  placeholderImage:nil
                           options:SDWebImageRetryFailed
                          progress:progressHandler
                         completed:completionHandler];

    // Loading actually starts a little before this, but this is the first time we know
    // the image is loading and can fire an event from this component
    static_cast<const ImageEventEmitter &>(*_eventEmitter).onLoadStart();

    // TODO (T58941612): Tracking for visibility should be done directly on this class.
    // For now, we consolidate instrumentation logic in the image loader, so that pre-Fabric gets the same treatment.
  }
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  [_imageView sd_cancelCurrentImageLoad];
  _imageView.image = nil;
}

#pragma mark - RCTImageResponseDelegate

- (void)didReceiveImage:(UIImage *)image
{
  if (!_eventEmitter || !_state) {
    // Notifications are delivered asynchronously and might arrive after the view is already recycled.
    // In the future, we should incorporate an `EventEmitter` into a separate object owned by `ImageRequest` or `State`.
    // See for more info: T46311063.
    return;
  }

  static_cast<const ImageEventEmitter &>(*_eventEmitter).onLoad();
  static_cast<const ImageEventEmitter &>(*_eventEmitter).onLoadEnd();

  const auto &imageProps = static_cast<const ImageProps &>(*_props);

  if (imageProps.tintColor) {
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  }

  if (imageProps.resizeMode == ImageResizeMode::Repeat) {
    image = [image resizableImageWithCapInsets:RCTUIEdgeInsetsFromEdgeInsets(imageProps.capInsets)
                                  resizingMode:UIImageResizingModeTile];
  } else if (imageProps.capInsets != EdgeInsets()) {
    // Applying capInsets of 0 will switch the "resizingMode" of the image to "tile" which is undesired.
    image = [image resizableImageWithCapInsets:RCTUIEdgeInsetsFromEdgeInsets(imageProps.capInsets)
                                  resizingMode:UIImageResizingModeStretch];
  }

  if (imageProps.blurRadius > __FLT_EPSILON__) {
    // Blur on a background thread to avoid blocking interaction.
    CGFloat blurRadius = imageProps.blurRadius;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      UIImage *blurredImage = RCTBlurredImageWithRadius(image, blurRadius);
      RCTExecuteOnMainQueue(^{
        self->_imageView.image = blurredImage;
      });
    });
  } else {
    self->_imageView.image = image;
  }
}

- (void)didReceiveProgress:(float)progress
{
  if (!_eventEmitter) {
    return;
  }

  static_cast<const ImageEventEmitter &>(*_eventEmitter).onProgress(progress);
}

- (void)didReceiveFailure
{
  _imageView.image = nil;

  if (!_eventEmitter) {
    return;
  }

  static_cast<const ImageEventEmitter &>(*_eventEmitter).onError();
  static_cast<const ImageEventEmitter &>(*_eventEmitter).onLoadEnd();
}

@end

#ifdef __cplusplus
extern "C" {
#endif

// Can't the import generated Plugin.h because plugins are not in this BUCK target
Class<RCTComponentViewProtocol> RCTImageCls(void);

#ifdef __cplusplus
}
#endif

Class<RCTComponentViewProtocol> RCTImageCls(void)
{
  return RCTImageComponentView.class;
}
