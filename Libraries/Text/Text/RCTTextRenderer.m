/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTTextRenderer.h"

#import "RCTTextAttributes.h"

@implementation RCTTextRenderer
{
  __weak CALayer *_layer;
  NSTextStorage *_Nullable _textStorage;
  CGRect _contentFrame;
  CAShapeLayer *_highlightLayer;
}

- (instancetype)initWithLayer:(CALayer *)layer
{
  self = [super init];
  if (self) {
    _layer = layer;
  }
  return self;
}

- (void)setTextStorage:(NSTextStorage *)textStorage
          contentFrame:(CGRect)contentFrame
{
  _textStorage = textStorage;
  _contentFrame = contentFrame;
}

- (void)drawLayer:(CALayer *)layer
        inContext:(CGContextRef)ctx;
{
  if (!_textStorage) {
    return;
  }

  CGRect boundingBox = CGContextGetClipBoundingBox(ctx);
  CGContextSaveGState(ctx);
  UIGraphicsPushContext(ctx);

  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;

  NSRange glyphRange =
  [layoutManager glyphRangeForBoundingRect:boundingBox
                           inTextContainer:textContainer];

  [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:_contentFrame.origin];
  [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:_contentFrame.origin];

  __block UIBezierPath *highlightPath = nil;
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                     actualGlyphRange:NULL];
  [_textStorage enumerateAttribute:RCTTextAttributesIsHighlightedAttributeName
                           inRange:characterRange
                           options:0
                        usingBlock:
   ^(NSNumber *value, NSRange range, __unused BOOL *stop) {
     if (!value.boolValue) {
       return;
     }

     [layoutManager enumerateEnclosingRectsForGlyphRange:range
                                withinSelectedGlyphRange:range
                                         inTextContainer:textContainer
                                              usingBlock:
      ^(CGRect enclosingRect, __unused BOOL *anotherStop) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(enclosingRect, -2, -2) cornerRadius:2];
        if (highlightPath) {
          [highlightPath appendPath:path];
        } else {
          highlightPath = path;
        }
      }
      ];
   }];

  if (highlightPath) {
    if (!_highlightLayer) {
      _highlightLayer = [CAShapeLayer layer];
      _highlightLayer.fillColor = [UIColor colorWithWhite:0 alpha:0.25].CGColor;
      [_layer addSublayer:_highlightLayer];
    }
    _highlightLayer.position = _contentFrame.origin;
    _highlightLayer.path = highlightPath.CGPath;
  } else {
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  }

  UIGraphicsPopContext();
  CGContextRestoreGState(ctx);
}

- (void)removeHighlightLayer
{
  if (_highlightLayer) {
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  }
}

@end
