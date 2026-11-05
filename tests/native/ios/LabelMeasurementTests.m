/**
 * Titanium SDK
 * Copyright TiDev, Inc. 04/07/2022-Present. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiUILabel.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

@interface TiUILabel (LabelMeasurementTests)
- (CGSize)sizeForFont:(CGFloat)suggestedWidth;
@end

static IMP originalSize;
static NSUInteger measureCount;

static CGSize countedSize(id self, SEL _cmd) {
  // Only sizeForFont: on the main thread is being counted, not other work in
  // the test host.
  if ([NSThread isMainThread]) {
    measureCount++;
  }
  return ((CGSize(*)(id, SEL))originalSize)(self, _cmd);
}

static NSAttributedString *attributedText(NSDictionary *attributes) {
  return [[[NSAttributedString alloc] initWithString:@"Same string"
                                          attributes:attributes] autorelease];
}

@interface LabelMeasurementTests : XCTestCase
@end

@implementation LabelMeasurementTests {
  TiUILabel *view;
}

+ (void)setUp {
  Method size =
      class_getInstanceMethod([NSAttributedString class], @selector(size));
  originalSize = method_getImplementation(size);
  method_setImplementation(size, (IMP)countedSize);
}

+ (void)tearDown {
  Method size =
      class_getInstanceMethod([NSAttributedString class], @selector(size));
  method_setImplementation(size, originalSize);
}

- (void)setUp {
  view = [[TiUILabel alloc] init];
}

- (void)tearDown {
  [view release];
  view = nil;
}

- (void)expectMeasures:(NSUInteger)count
              forWidth:(CGFloat)width
                  step:(NSString *)step {
  measureCount = 0;
  CGSize actual = [view sizeForFont:width];
  XCTAssertEqual(measureCount, count, @"%@: measure count", step);

  NSAttributedString *copied =
      [[[[view label] attributedText] copy] autorelease];
  CGSize fresh = [copied size];
  XCTAssertEqual(actual.width, ceilf(fresh.width), @"%@: width", step);
  XCTAssertEqual(actual.height, ceilf(fresh.height), @"%@: height", step);
}

- (void)expectMeasures:(NSUInteger)count step:(NSString *)step {
  [self expectMeasures:count forWidth:0 step:step];
}

- (void)testMeasuresOnlyWhenPlainTextOrFontChanges {
  UILabel *label = [view label];

  label.text = @"Measured text";
  // Also proves that the swizzled method is the one sizeForFont: calls.
  [self expectMeasures:1 step:@"first measure"];
  [self expectMeasures:0 step:@"repeat"];
  [self expectMeasures:0 forWidth:120 step:@"repeat with another width"];

  label.text = @"Measured text that is longer";
  [self expectMeasures:1 step:@"changed text"];
  label.text = @"Measured text that is longer";
  [self expectMeasures:0 step:@"same text again"];

  label.font = [UIFont boldSystemFontOfSize:40];
  [self expectMeasures:1 step:@"changed font"];
  [self expectMeasures:0 step:@"repeat after font"];

  label.text = @"Measured text";
  [self expectMeasures:1 step:@"earlier text"];
}

- (void)testMeasuresOnlyWhenAttributesChange {
  UILabel *label = [view label];
  NSDictionary *font = @{NSFontAttributeName : [UIFont systemFontOfSize:40]};
  NSDictionary *smallerFont =
      @{NSFontAttributeName : [UIFont systemFontOfSize:14]};
  NSDictionary *kerning = @{
    NSFontAttributeName : [UIFont systemFontOfSize:14],
    NSKernAttributeName : @20
  };
  NSDictionary *color = @{
    NSFontAttributeName : [UIFont systemFontOfSize:14],
    NSKernAttributeName : @20,
    NSForegroundColorAttributeName : [UIColor redColor]
  };

  label.attributedText = attributedText(font);
  [self expectMeasures:1 step:@"first measure"];

  label.attributedText = attributedText(font);
  [self expectMeasures:0 step:@"equal content, new instance"];

  label.attributedText = attributedText(smallerFont);
  [self expectMeasures:1 step:@"changed font attribute"];

  label.attributedText = attributedText(kerning);
  [self expectMeasures:1 step:@"changed kerning"];

  label.attributedText = attributedText(color);
  [self expectMeasures:1 step:@"changed color only"];

  label.attributedText = attributedText(color);
  [self expectMeasures:0 step:@"equal color, new instance"];
}

@end
