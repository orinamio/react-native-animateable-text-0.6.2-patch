/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "JBBaseTextShadowView.h"

#import <React/RCTShadowView+Layout.h>

#import <React/RCTRawTextShadowView.h>
#import <React/RCTVirtualTextShadowView.h>

NSString *const JBBaseTextShadowViewEmbeddedShadowViewAttributeName = @"JBBaseTextShadowViewEmbeddedShadowViewAttributeName";

static void RCTInlineViewYogaNodeDirtied(YGNodeRef node)
{
  // An inline view (a view nested inside of a text node) does not have a parent
  // in the Yoga tree. Consequently, we have to manually propagate the inline
  // view's dirty signal up through the text nodes. At some point, it'll reach
  // the outermost text node which has a Yoga node and then Yoga will take over
  // the dirty signal propagation.
  RCTShadowView *inlineView = (__bridge RCTShadowView *)YGNodeGetContext(node);
  JBBaseTextShadowView *baseTextShadowView =
    (JBBaseTextShadowView *)inlineView.reactSuperview;

  [baseTextShadowView dirtyLayout];
}

@implementation JBBaseTextShadowView

- (instancetype)init
{
  if (self = [super init]) {
    _textAttributes = [JBTextAttributes new];
  }

  return self;
}

- (void)setReactTag:(NSNumber *)reactTag
{
  [super setReactTag:reactTag];
  _textAttributes.tag = reactTag;
}

#pragma mark - Life Cycle

- (void)insertReactSubview:(RCTShadowView *)subview atIndex:(NSInteger)index
{
  [super insertReactSubview:subview atIndex:index];

  [self dirtyLayout];

  if (![subview isKindOfClass:[RCTVirtualTextShadowView class]]) {
    YGNodeSetDirtiedFunc(subview.yogaNode, RCTInlineViewYogaNodeDirtied);
  }
}

- (void)removeReactSubview:(RCTShadowView *)subview
{
  if (![subview isKindOfClass:[RCTVirtualTextShadowView class]]) {
    YGNodeSetDirtiedFunc(subview.yogaNode, NULL);
  }

  [self dirtyLayout];

  [super removeReactSubview:subview];
}

#pragma mark - attributedString

- (NSAttributedString *)attributedTextWithBaseTextAttributes:(nullable JBTextAttributes *)baseTextAttributes
{
  JBTextAttributes *textAttributes;

  if (baseTextAttributes) {
    textAttributes = [baseTextAttributes copy];
    [textAttributes applyTextAttributes:self.textAttributes];
  } else {
    textAttributes = [self.textAttributes copy];
  }

  if (cachedAttributedText && [cachedTextAttributes isEqual:textAttributes]) {
    return cachedAttributedText;
  }

  NSMutableAttributedString *attributedText = [NSMutableAttributedString new];

  [attributedText beginEditing];
  if (_textAttributes.text && _textAttributes.text.length > 0) {
    NSAttributedString *rawTextAttributedString =
      [[NSAttributedString alloc] initWithString:[textAttributes applyTextAttributesToText:_textAttributes.text] attributes:textAttributes.effectiveTextAttributes];
    [attributedText appendAttributedString:rawTextAttributedString];
  }

  for (RCTShadowView *shadowView in self.reactSubviews) {

    // Special Case: JBBaseTextShadowView
    if ([shadowView isKindOfClass:[JBBaseTextShadowView class]]) {
      JBBaseTextShadowView *baseTextShadowView = (JBBaseTextShadowView *)shadowView;
      NSAttributedString *baseTextAttributedString =
        [baseTextShadowView attributedTextWithBaseTextAttributes:textAttributes];
      [attributedText appendAttributedString:baseTextAttributedString];
      continue;
    }

    // Generic Case: Any RCTShadowView
    NSTextAttachment *attachment = [NSTextAttachment new];
    NSMutableAttributedString *embeddedShadowViewAttributedString = [NSMutableAttributedString new];
    [embeddedShadowViewAttributedString beginEditing];
    [embeddedShadowViewAttributedString appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
    [embeddedShadowViewAttributedString addAttribute:JBBaseTextShadowViewEmbeddedShadowViewAttributeName
                                               value:shadowView
                                               range:(NSRange){0, embeddedShadowViewAttributedString.length}];
    [embeddedShadowViewAttributedString endEditing];
    [attributedText appendAttributedString:embeddedShadowViewAttributedString];
  }

  [attributedText endEditing];

  [self clearLayout];

  cachedAttributedText = [attributedText copy];
  cachedTextAttributes = textAttributes;

  return cachedAttributedText;
}

- (void)dirtyLayout
{
  [super dirtyLayout];
  cachedAttributedText = nil;
  cachedTextAttributes = nil;
}

- (void)didUpdateReactSubviews
{
  [super didUpdateReactSubviews];
  [self dirtyLayout];
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
  [super didSetProps:changedProps];
  [self dirtyLayout];
}

@end
