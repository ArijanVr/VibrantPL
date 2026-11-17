/* SPDX-FileCopyrightText: 2026 ARJO LAB */
/* SPDX-License-Identifier: GPL-3.0-or-later */

#import "SystemSpeechBridge.h"
#import <AppKit/AppKit.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@interface SystemSpeechBridge () <NSSpeechSynthesizerDelegate>
@property (nonatomic, strong) NSSpeechSynthesizer *speaker;
@end

@implementation SystemSpeechBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        _speaker = [[NSSpeechSynthesizer alloc] init];
        _speaker.delegate = self;
    }
    return self;
}

- (void)speak:(NSString *)text rate:(float)rate {
    [self.speaker stopSpeaking];
    self.speaker.rate = rate;
    [self.speaker startSpeakingString:text];
}

- (void)stop {
    [self.speaker stopSpeaking];
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)finishedSpeaking {
    if (finishedSpeaking && self.onFinished) {
        self.onFinished();
    }
}

@end

#pragma clang diagnostic pop
