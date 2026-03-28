#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "aaplcad/aaplcad.h"
#include "aaplcad/core/log.h"
#include "aaplcad/platform/input_event.h"
#include "aaplcad/platform/platform.h"

#include <string>

static std::uint32_t mapModifiers(NSEventModifierFlags flags) {
    using namespace aaplcad::platform;

    std::uint32_t modifiers = modifierNone;
    if ((flags & NSEventModifierFlagShift) != 0) {
        modifiers |= modifierShift;
    }
    if ((flags & NSEventModifierFlagControl) != 0) {
        modifiers |= modifierControl;
    }
    if ((flags & NSEventModifierFlagOption) != 0) {
        modifiers |= modifierOption;
    }
    if ((flags & NSEventModifierFlagCommand) != 0) {
        modifiers |= modifierCommand;
    }
    return modifiers;
}

static aaplcad::platform::PointerEvent makePointerEvent(NSEvent* event, aaplcad::platform::InputAction action) {
    const NSPoint location = [event locationInWindow];
    return {
        [event hasPreciseScrollingDeltas] ? aaplcad::platform::InputDevice::trackpad : aaplcad::platform::InputDevice::mouse,
        action,
        location.x,
        location.y,
        [event scrollingDeltaX],
        [event scrollingDeltaY],
        mapModifiers([event modifierFlags]),
    };
}

@interface AAPLViewerView : MTKView <MTKViewDelegate>
@end

@implementation AAPLViewerView

- (instancetype)initWithFrame:(NSRect)frameRect device:(id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    if (self != nil) {
        self.delegate = self;
        self.clearColor = MTLClearColorMake(0.10, 0.12, 0.16, 1.0);
        self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        self.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        self.preferredFramesPerSecond = 60;
        self.enableSetNeedsDisplay = NO;
        self.paused = NO;
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)drawInMTKView:(MTKView*)view {
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (drawable == nil || renderPassDescriptor == nil) {
        return;
    }

    id<MTLCommandQueue> commandQueue = [self.device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
    (void)view;
    (void)size;
}

- (void)scrollWheel:(NSEvent*)event {
    const std::string message = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::scroll));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, message);
    [super scrollWheel:event];
}

- (void)mouseDown:(NSEvent*)event {
    const std::string message = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::buttonDown));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, message);
    [super mouseDown:event];
}

- (void)mouseDragged:(NSEvent*)event {
    const std::string message = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::move));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, message);
    [super mouseDragged:event];
}

@end

static void terminateFromTimer(NSTimer* timer) {
    (void)timer;
    [NSApp terminate:nil];
}

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        bool smokeTest = false;
        for (int index = 1; index < argc; ++index) {
            if (std::string{argv[index]} == "--smoke-test") {
                smokeTest = true;
            }
        }

        const auto platform = aaplcad::platform::currentPlatform();
        aaplcad::core::logMessage(aaplcad::core::LogLevel::info, "AAPLCAD macOS Metal viewer starting");
        aaplcad::core::logMessage(aaplcad::core::LogLevel::info, platform.description());

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            aaplcad::core::logMessage(aaplcad::core::LogLevel::error, "Metal device unavailable");
            return 1;
        }

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect frame = NSMakeRect(0, 0, 960, 640);
        NSWindow* window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:(NSWindowStyleMaskTitled |
                                                                  NSWindowStyleMaskClosable |
                                                                  NSWindowStyleMaskMiniaturizable |
                                                                  NSWindowStyleMaskResizable)
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setTitle:@"AAPLCAD macOS Viewer Prototype"];

        AAPLViewerView* metalView = [[AAPLViewerView alloc] initWithFrame:frame device:device];
        [window setContentView:metalView];
        [window makeFirstResponder:metalView];
        [window center];
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        if (smokeTest) {
            [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:NO block:^(NSTimer* timer) {
                terminateFromTimer(timer);
            }];
        }

        [NSApp run];
    }

    return 0;
}
