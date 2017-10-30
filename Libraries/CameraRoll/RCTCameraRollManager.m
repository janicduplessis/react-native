/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTCameraRollManager.h"

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTImageLoader.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import "RCTAssetsLibraryRequestHandler.h"

@implementation RCTConvert (ALAssetGroup)

RCT_ENUM_CONVERTER(ALAssetsGroupType, (@{

  // New values
  @"album": @(ALAssetsGroupAlbum),
  @"all": @(ALAssetsGroupAll),
  @"event": @(ALAssetsGroupEvent),
  @"faces": @(ALAssetsGroupFaces),
  @"library": @(ALAssetsGroupLibrary),
  @"photo-stream": @(ALAssetsGroupPhotoStream),
  @"saved-photos": @(ALAssetsGroupSavedPhotos),

  // Legacy values
  @"Album": @(ALAssetsGroupAlbum),
  @"All": @(ALAssetsGroupAll),
  @"Event": @(ALAssetsGroupEvent),
  @"Faces": @(ALAssetsGroupFaces),
  @"Library": @(ALAssetsGroupLibrary),
  @"PhotoStream": @(ALAssetsGroupPhotoStream),
  @"SavedPhotos": @(ALAssetsGroupSavedPhotos),

}), ALAssetsGroupSavedPhotos, integerValue)

static Class _ALAssetsFilter = nil;
static NSString *_ALAssetsGroupPropertyName = nil;
static NSString *_ALAssetPropertyAssetURL = nil;
static NSString *_ALAssetPropertyLocation = nil;
static NSString *_ALAssetPropertyDate = nil;
static NSString *_ALAssetPropertyType = nil;
static NSString *_ALAssetPropertyDuration = nil;
static NSString *_ALAssetTypeVideo = nil;
static NSString *lookupNSString(void * handle, const char * name)
{
  void ** sym = dlsym(handle, name);
  return (__bridge NSString *)(sym ? *sym : nil);
}
static void ensureAssetsLibLoaded(void)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    void * handle = dlopen("/System/Library/Frameworks/AssetsLibrary.framework/AssetsLibrary", RTLD_LAZY);
    RCTAssert(handle != NULL, @"Unable to load AssetsLibrary.framework.");
    _ALAssetsFilter = objc_getClass("ALAssetsFilter");
    _ALAssetsGroupPropertyName = lookupNSString(handle, "ALAssetsGroupPropertyName");
    _ALAssetPropertyAssetURL = lookupNSString(handle, "ALAssetPropertyAssetURL");
    _ALAssetPropertyLocation = lookupNSString(handle, "ALAssetPropertyLocation");
    _ALAssetPropertyDate = lookupNSString(handle, "ALAssetPropertyDate");
    _ALAssetPropertyType = lookupNSString(handle, "ALAssetPropertyType");
    _ALAssetPropertyDuration = lookupNSString(handle, "ALAssetPropertyDuration");
    _ALAssetTypeVideo = lookupNSString(handle, "ALAssetTypeVideo");
  });
}

+ (ALAssetsFilter *)ALAssetsFilter:(id)json
{
  static NSDictionary<NSString *, ALAssetsFilter *> *options;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ensureAssetsLibLoaded();
    options = @{
      // New values
      @"photos": [_ALAssetsFilter allPhotos],
      @"videos": [_ALAssetsFilter allVideos],
      @"all": [_ALAssetsFilter allAssets],

      // Legacy values
      @"Photos": [_ALAssetsFilter allPhotos],
      @"Videos": [_ALAssetsFilter allVideos],
      @"All": [_ALAssetsFilter allAssets],
    };
  });

  ALAssetsFilter *filter = options[json ?: @"photos"];
  if (!filter) {
    RCTLogError(@"Invalid filter option: '%@'. Expected one of 'photos',"
                "'videos' or 'all'.", json);
  }
  return filter ?: [_ALAssetsFilter allPhotos];
}

RCT_ENUM_CONVERTER(PHAssetMediaType, (@{
  @"photos": @(PHAssetMediaTypeImage),
  @"videos": @(PHAssetMediaTypeVideo),
  @"audio": @(PHAssetMediaTypeAudio),
  // PHAssetMediaType doesn't have a value to represent 'all' so use PHAssetMediaTypeUnknown
  // since it isn't used for anything else.
  @"all": @(PHAssetMediaTypeUnknown),
}), PHAssetMediaTypeImage, integerValue)

@end

@implementation RCTCameraRollManager

RCT_EXPORT_MODULE()

@synthesize bridge = _bridge;

static NSString *const kErrorUnableToLoad = @"E_UNABLE_TO_LOAD";
static NSString *const kErrorUnableToSave = @"E_UNABLE_TO_SAVE";

RCT_EXPORT_METHOD(saveToCameraRoll:(NSURLRequest *)request
                  type:(NSString *)type
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  if ([type isEqualToString:@"video"]) {
    // It's unclear if writeVideoAtPathToSavedPhotosAlbum is thread-safe
    dispatch_async(dispatch_get_main_queue(), ^{
      [self->_bridge.assetsLibrary writeVideoAtPathToSavedPhotosAlbum:request.URL completionBlock:^(NSURL *assetURL, NSError *saveError) {
        if (saveError) {
          reject(kErrorUnableToSave, nil, saveError);
        } else {
          resolve(assetURL.absoluteString);
        }
      }];
    });
  } else {
    [_bridge.imageLoader loadImageWithURLRequest:request
                                        callback:^(NSError *loadError, UIImage *loadedImage) {
      if (loadError) {
        reject(kErrorUnableToLoad, nil, loadError);
        return;
      }
      // It's unclear if writeImageToSavedPhotosAlbum is thread-safe
      dispatch_async(dispatch_get_main_queue(), ^{
        [self->_bridge.assetsLibrary writeImageToSavedPhotosAlbum:loadedImage.CGImage metadata:nil completionBlock:^(NSURL *assetURL, NSError *saveError) {
          if (saveError) {
            RCTLogWarn(@"Error saving cropped image: %@", saveError);
            reject(kErrorUnableToSave, nil, saveError);
          } else {
            resolve(assetURL.absoluteString);
          }
        }];
      });
    }];
  }
}

static void RCTResolvePromise(RCTPromiseResolveBlock resolve,
                              NSArray<NSDictionary<NSString *, id> *> *assets,
                              BOOL hasNextPage)
{
  if (!assets.count) {
    resolve(@{
      @"edges": assets,
      @"page_info": @{
        @"has_next_page": @NO,
      }
    });
    return;
  }
  resolve(@{
    @"edges": assets,
    @"page_info": @{
      @"start_cursor": assets[0][@"node"][@"image"][@"uri"],
      @"end_cursor": assets[assets.count - 1][@"node"][@"image"][@"uri"],
      @"has_next_page": @(hasNextPage),
    }
  });
}

RCT_EXPORT_METHOD(getPhotos:(NSDictionary *)params
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  checkPhotoLibraryConfig();

  ensureAssetsLibLoaded();
  NSUInteger first = [RCTConvert NSInteger:params[@"first"]];
  NSString *afterCursor = [RCTConvert NSString:params[@"after"]];
  PHAssetMediaType assetType = [RCTConvert PHAssetMediaType:params[@"assetType"]];
  NSString *collectionLocalIdentifier = [RCTConvert NSString:params[@"collection"]];

  PHAssetCollection *collection =
    [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[collectionLocalIdentifier]
                                                         options:nil].firstObject;
  if (collection == nil) {
    reject(
      kErrorUnableToLoad,
      [NSString stringWithFormat:@"Cannot find asset collection with id '%@'.", collectionLocalIdentifier],
      nil
    );
    return;
  }

  PHFetchOptions *options = [PHFetchOptions new];
  // PHAssetMediaTypeUnknown means no media type filter.
  if (assetType != PHAssetMediaTypeUnknown) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", assetType];
  }
  PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:collection options:options];

  BOOL __block foundAfter = NO;
  BOOL __block hasNextPage = NO;
  BOOL __block resolvedPromise = NO;
  NSMutableArray<NSDictionary<NSString *, id> *> *results = [NSMutableArray new];

  [assets enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PHAsset * _Nonnull asset, NSUInteger idx, BOOL * _Nonnull stop) {
    NSString *uri = [NSString stringWithFormat:@"ph://%@", asset.localIdentifier];
    if (afterCursor && !foundAfter) {
      if ([afterCursor isEqualToString:uri]) {
        foundAfter = YES;
      }
      return; // Skip until we get to the first one
    }
    if (first == results.count) {
      hasNextPage = YES;
      RCTAssert(resolvedPromise == NO, @"Resolved the promise before we finished processing the results.");
      RCTResolvePromise(resolve, results, hasNextPage);
      resolvedPromise = YES;
      *stop = YES;
      return;
    }
    CGSize dimensions = (CGSize){asset.pixelWidth, asset.pixelHeight};
    CLLocation *loc = asset.location;
    NSDate *date = asset.creationDate;
    // NSString *filename = [result defaultRepresentation].filename;
    int64_t duration = asset.duration;

    [results addObject:@{
      @"node": @{
        @"type": @(asset.mediaType),
        @"group_name": collection.localizedTitle,
        @"image": @{
            @"uri": uri,
            // @"filename" : filename,
            @"height": @(dimensions.height),
            @"width": @(dimensions.width),
            @"isStored": @YES,
            @"playableDuration": @(duration),
            },
        @"timestamp": @(date.timeIntervalSince1970),
        @"location": loc ? @{
          @"latitude": @(loc.coordinate.latitude),
          @"longitude": @(loc.coordinate.longitude),
          @"altitude": @(loc.altitude),
          @"heading": @(loc.course),
          @"speed": @(loc.speed),
        } : @{},
      }
    }];
  }];

  if (!resolvedPromise) {
    RCTResolvePromise(resolve, results, hasNextPage);
  }
}

RCT_EXPORT_METHOD(getCollections:(NSDictionary *)params
                         resolve:(RCTPromiseResolveBlock)resolve
                          reject:(RCTPromiseRejectBlock)reject)
{
  checkPhotoLibraryConfig();

  PHAssetMediaType assetType = [RCTConvert PHAssetMediaType:params[@"assetType"]];
  PHFetchOptions *options = [PHFetchOptions new];
  // PHAssetMediaTypeUnknown means no media type filter.
  if (assetType != PHAssetMediaTypeUnknown) {
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", assetType];
  }

  PHFetchResult<PHAssetCollection *> *smartAlbumCollections =
    [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                             subtype:PHAssetCollectionSubtypeAlbumRegular
                                             options:nil];
  PHFetchResult<PHCollection *> *userCollections =
    [PHAssetCollection fetchTopLevelUserCollectionsWithOptions:nil];

  NSMutableArray *results = [NSMutableArray new];
  void (^addToResultsBlock)(PHCollection * _Nonnull, NSUInteger, BOOL * _Nonnull) =
    ^(PHCollection * _Nonnull collection, NSUInteger idx, BOOL * _Nonnull stop) {
      if ([collection isKindOfClass:[PHAssetCollection class]]) {
        PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
        NSUInteger estimatedAssetCount = assetCollection.estimatedAssetCount;
        // If we filter by asset type we can't rely on estimatedAssetCount since it includes
        // assets of all types.
        if (estimatedAssetCount == NSNotFound || assetType != PHAssetMediaTypeUnknown) {
          PHFetchResult<PHAsset *> *assets =
            [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
          estimatedAssetCount = assets.count;
        }
        [results addObject:@{
          @"id": assetCollection.localIdentifier,
          @"title": assetCollection.localizedTitle,
          @"estimatedAssetCount": @(estimatedAssetCount),
        }];
      }
  };

  [smartAlbumCollections enumerateObjectsUsingBlock:addToResultsBlock];
  [userCollections enumerateObjectsUsingBlock:addToResultsBlock];

  resolve(results);
}

RCT_EXPORT_METHOD(deletePhotos:(NSArray<NSString *>*)assets
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSArray<NSURL *> *assets_ = [RCTConvert NSURLArray:assets];
  [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
      PHFetchResult<PHAsset *> *fetched =
        [PHAsset fetchAssetsWithALAssetURLs:assets_ options:nil];
      [PHAssetChangeRequest deleteAssets:fetched];
    }
  completionHandler:^(BOOL success, NSError *error) {
      if (success == YES) {
     	    resolve(@(success));
      }
      else {
	        reject(@"Couldn't delete", @"Couldn't delete assets", error);
      }
    }
    ];
}

static void checkPhotoLibraryConfig()
{
#if RCT_DEV
  if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSPhotoLibraryUsageDescription"]) {
    RCTLogError(@"NSPhotoLibraryUsageDescription key must be present in Info.plist to use camera roll.");
  }
#endif
}

@end
