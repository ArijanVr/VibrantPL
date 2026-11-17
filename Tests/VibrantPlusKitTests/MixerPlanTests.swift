// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import VibrantPlusKit

struct MixerPlanTests {
    @Test func tapOnlyWhenGainOrOutputDiffers() {
        #expect(!MixerPlan.needsTap(gain: 1, outputUID: nil))
        #expect(!MixerPlan.needsTap(gain: 1.01, outputUID: "  "))
        #expect(MixerPlan.needsTap(gain: 0.5, outputUID: nil))
        #expect(MixerPlan.needsTap(gain: 1, outputUID: "BuiltInSpeakerDevice"))
        #expect(MixerPlan.clampedGain(9) == 2)
        #expect(MixerPlan.clampedGain(-1) == 0)
        #expect(MixerPlan.storedOutput("  ") == nil)
        #expect(MixerPlan.storedOutput("uid-1") == "uid-1")
    }

    @Test func favoriteToggleIsStable() {
        let first = MixerPlan.togglingFavorite("com.apple.Music", in: MixerMemory())
        #expect(first.favorites == ["com.apple.Music"])
        let gone = MixerPlan.togglingFavorite("com.apple.Music", in: first)
        #expect(gone.favorites.isEmpty)
        #expect(MixerPlan.togglingFavorite("", in: MixerMemory()).favorites.isEmpty)
    }
}

struct GIFPlanTests {
    @Test func capsDurationAndSize() {
        let range = GIFPlan.clampedRange(duration: 60, start: 0, end: 60)
        #expect(range.end - range.start == GIFPlan.maxDuration)
        #expect(GIFPlan.frameTimes(duration: 1).count == 10)
        #expect(GIFPlan.frameTimes(duration: 0).isEmpty)
        let size = GIFPlan.scaledSize(width: 1920, height: 1080)
        #expect(size.width == 480 && size.height == 270)
        #expect(GIFPlan.scaledSize(width: 320, height: 240) == (320, 240))
    }
}
