/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTBlobManager.h"

#import <React/RCTConvert.h>
#import <React/RCTWebSocketModule.h>
#import <React/RCTNetworking.h>

static NSString *const kBlobUriScheme = @"blob";

@interface _RCTBlobWebSocketContentHandler : NSObject <RCTWebSocketContentHandler>

- (instancetype)initWithBlobManager:(RCTBlobManager *)blobManager;

@end

@interface _RCTBlobXMLHttpRequestContentHandler : NSObject <RCTXMLHttpRequestContentHandler>

- (instancetype)initWithBlobManager:(RCTBlobManager *)blobManager;

@end

@implementation RCTBlobManager
{
  NSMutableDictionary<NSString *, NSData *> *_blobs;
  _RCTBlobWebSocketContentHandler *_webSocketContentHandler;
  _RCTBlobXMLHttpRequestContentHandler *_xmlHttpRequestContentHandler;
  NSOperationQueue *_queue;
}

RCT_EXPORT_MODULE(BlobModule)

@synthesize bridge = _bridge;

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
  return @{
    @"BLOB_URI_SCHEME": kBlobUriScheme,
    @"BLOB_URI_HOST": [NSNull null],
  };
}

- (dispatch_queue_t)methodQueue
{
  return [[_bridge webSocketModule] methodQueue];
}

- (NSString *)store:(NSData *)data
{
  NSString *blobId = [NSUUID UUID].UUIDString;
  [self store:data withId:blobId];
  return blobId;
}

- (void)store:(NSData *)data withId:(NSString *)blobId
{
  if (!_blobs) {
    _blobs = [NSMutableDictionary new];
  }
  _blobs[blobId] = data;
}

- (NSData *)resolve:(NSDictionary<NSString *, id> *)blob
{
  NSString *blobId = [RCTConvert NSString:blob[@"blobId"]];
  NSNumber *offset = [RCTConvert NSNumber:blob[@"offset"]];
  NSNumber *size = [RCTConvert NSNumber:blob[@"size"]];
  return [self resolve:blobId
                offset:offset ? [offset integerValue] : 0
                  size:size ? [size integerValue] : -1];
}

- (NSData *)resolve:(NSString *)blobId offset:(NSInteger)offset size:(NSInteger)size
{
  NSData *data = _blobs[blobId];
  if (!data) {
    return nil;
  }
  if (offset != 0 || (size != -1 && size != data.length)) {
    data = [data subdataWithRange:NSMakeRange(offset, size)];
  }
  return data;
}

RCT_EXPORT_METHOD(addXMLHttpRequestHandler)
{
  if (!_xmlHttpRequestContentHandler) {
    _xmlHttpRequestContentHandler = [[_RCTBlobXMLHttpRequestContentHandler alloc] initWithBlobManager:self];
  }
  [[_bridge networking] setContentHandler:_xmlHttpRequestContentHandler];
}

RCT_EXPORT_METHOD(removeXMLHttpRequestHandler)
{
  [[_bridge networking] setContentHandler:nil];
}

RCT_EXPORT_METHOD(addWebSocketHandler:(nonnull NSNumber *)socketID)
{
  if (!_webSocketContentHandler) {
    _webSocketContentHandler = [[_RCTBlobWebSocketContentHandler alloc] initWithBlobManager:self];
  }
  [[_bridge webSocketModule] setContentHandler:_webSocketContentHandler forSocketID:socketID];
}

RCT_EXPORT_METHOD(removeWebSocketHandler:(nonnull NSNumber *)socketID)
{
  [[_bridge webSocketModule] setContentHandler:nil forSocketID:socketID];
}

RCT_EXPORT_METHOD(sendOverSocket:(NSDictionary *)blob socketID:(nonnull NSNumber *)socketID)
{
  [[_bridge webSocketModule] sendData:[self resolve:blob] forSocketID:socketID];
}

RCT_EXPORT_METHOD(createFromParts:(NSArray<NSDictionary<NSString *, id> *> *)parts withId:(NSString *)blobId)
{
  NSMutableData *data = [NSMutableData new];
  for (NSDictionary<NSString *, id> *part in parts) {
    NSString *type = [RCTConvert NSString:part[@"type"]];

    if ([type isEqualToString:@"blob"]) {
      NSData *partData = [self resolve:part];
      [data appendData:partData];
    } else if ([type isEqualToString:@"string"]) {
      NSData *partData = [[RCTConvert NSString:part[@"data"]] dataUsingEncoding:NSUTF8StringEncoding];
      [data appendData:partData];
    } else {
      [NSException raise:@"Invalid type for blob" format:@"%@ is invalid", type];
    }
  }
  [self store:data withId:blobId];
}

RCT_EXPORT_METHOD(release:(NSString *)blobId)
{
  [_blobs removeObjectForKey:blobId];
}

#pragma mark - RCTURLRequestHandler methods

- (BOOL)canHandleRequest:(NSURLRequest *)request
{
  return [request.URL.scheme caseInsensitiveCompare:kBlobUriScheme] == NSOrderedSame;
}

- (id)sendRequest:(NSURLRequest *)request withDelegate:(id<RCTURLRequestDelegate>)delegate
{
  // Lazy setup
  if (!_queue) {
    _queue = [NSOperationQueue new];
    _queue.maxConcurrentOperationCount = 2;
  }

  __weak __block NSBlockOperation *weakOp;
  __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                        MIMEType:nil
                                           expectedContentLength:-1
                                                textEncodingName:nil];

    [delegate URLRequest:weakOp didReceiveResponse:response];

    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:request.URL resolvingAgainstBaseURL:NO];

    NSString *blobId = components.path;
    NSInteger offset = 0;
    NSInteger size = -1;

    if (components.queryItems) {
      for (NSURLQueryItem *queryItem in components.queryItems) {
        if ([queryItem.name isEqualToString:@"offset"]) {
          offset = [queryItem.value integerValue];
        }
        if ([queryItem.name isEqualToString:@"size"]) {
          size = [queryItem.value integerValue];
        }
      }
    }

    NSData *data;
    if (blobId) {
      data = [self resolve:blobId offset:offset size:size];
    }
    NSError *error;
    if (data) {
      [delegate URLRequest:weakOp didReceiveData:data];
    } else {
      error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
    }
    [delegate URLRequest:weakOp didCompleteWithError:error];
  }];

  weakOp = op;
  [_queue addOperation:op];
  return op;
}

- (void)cancelRequest:(NSOperation *)op
{
  [op cancel];
}

@end

@implementation _RCTBlobWebSocketContentHandler {
  __weak RCTBlobManager *_blobManager;
}

- (instancetype)initWithBlobManager:(RCTBlobManager *)blobManager
{
  if (self = [super init]) {
    _blobManager = blobManager;
  }
  return self;
}

- (id)processMessage:(id)message forSocketID:(NSNumber *)socketID withType:(NSString *__autoreleasing _Nonnull *)type
{
  if (![message isKindOfClass:[NSData class]]) {
    *type = @"text";
    return message;
  }

  *type = @"blob";
  return @{
     @"blobId": [_blobManager store:message],
     @"offset": @0,
     @"size": @(((NSData *)message).length),
   };
}

@end

@implementation _RCTBlobXMLHttpRequestContentHandler {
  __weak RCTBlobManager *_blobManager;
}

-(instancetype)initWithBlobManager:(RCTBlobManager *)blobManager
{
  if (self = [super init]) {
    _blobManager = blobManager;
  }
  return self;
}

- (NSData *)processBlob:(NSDictionary *)blob {
  return [_blobManager resolve:blob];
}

- (NSString *)storeBlob:(NSData *)data {
  return [_blobManager store:data];
}

@end
