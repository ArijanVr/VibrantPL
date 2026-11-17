/* SPDX-FileCopyrightText: 2026 ARJO LAB */
/* SPDX-License-Identifier: GPL-3.0-or-later */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Speaks with the Mac's Spoken Content / Siri voice (NSSpeechSynthesizer).
/// Isolated in Objective-C so Swift stays free of deprecation warnings.
@interface SystemSpeechBridge : NSObject
@property (nonatomic, copy, nullable) void (^onFinished)(void);
- (void)speak:(NSString *)text rate:(float)rate;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
