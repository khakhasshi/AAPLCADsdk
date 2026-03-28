#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "aaplcad/aaplcad.h"
#include "aaplcad/core/log.h"
#include "aaplcad/database/document.h"
#include "aaplcad/database/line_entity.h"
#include "aaplcad/geometry/line2d.h"
#include "aaplcad/graphics/draw_list_2d.h"
#include "aaplcad/graphics/view_state_2d.h"
#include "aaplcad/platform/input_event.h"
#include "aaplcad/platform/platform.h"

#include <array>
#include <memory>
#include <string>

struct ViewerVertex {
    float position[2];
};

static NSString* const kAAPLCADLineShaderSource = @R"(
#include <metal_stdlib>
using namespace metal;

struct ViewerVertex {
    float2 position;
};

vertex float4 lineVertex(const device ViewerVertex* vertices [[buffer(0)]],
                         uint vertexId [[vertex_id]]) {
    return float4(vertices[vertexId].position, 0.0, 1.0);
}

fragment float4 lineFragment() {
    return float4(0.89, 0.77, 0.27, 1.0);
}
)";

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

@interface AAPLViewerView : MTKView <MTKViewDelegate> {
@private
    aaplcad::graphics::ViewState2d _viewState;
    aaplcad::database::Document _document;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _linePipelineState;
}
@end

@implementation AAPLViewerView

- (void)populateDemoDocument {
    const auto layerResult = _document.addLayer("demo");
    if (!layerResult.ok() && layerResult.error().code != "E_LAYER_EXISTS") {
        aaplcad::core::logMessage(aaplcad::core::LogLevel::error, "failed to create demo layer");
        return;
    }

    auto firstLine = std::make_unique<aaplcad::database::LineEntity>(
        aaplcad::geometry::Line2d{{120.0, 120.0}, {420.0, 220.0}});
    firstLine->setLayerName("demo");
    (void)_document.addEntity(std::move(firstLine));

    auto secondLine = std::make_unique<aaplcad::database::LineEntity>(
        aaplcad::geometry::Line2d{{180.0, 320.0}, {520.0, 160.0}});
    secondLine->setLayerName("demo");
    (void)_document.addEntity(std::move(secondLine));
}

- (id<MTLRenderPipelineState>)buildLinePipelineForDevice:(id<MTLDevice>)device {
    NSError* error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:kAAPLCADLineShaderSource options:nil error:&error];
    if (library == nil) {
        const std::string message = error != nil ? [[error localizedDescription] UTF8String] : "failed to compile line shaders";
        aaplcad::core::logMessage(aaplcad::core::LogLevel::error, message);
        return nil;
    }

    MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = [library newFunctionWithName:@"lineVertex"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"lineFragment"];
    descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;

    id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (pipelineState == nil) {
        const std::string message = error != nil ? [[error localizedDescription] UTF8String] : "failed to create line pipeline";
        aaplcad::core::logMessage(aaplcad::core::LogLevel::error, message);
    }
    return pipelineState;
}

- (std::array<ViewerVertex, 2>)clipSpaceVerticesForSegment:(const aaplcad::graphics::LineSegment2d&)segment drawableSize:(CGSize)drawableSize {
    const auto mapPoint = ^ViewerVertex(aaplcad::geometry::Point2d point) {
        const double ndcX = (point.x / drawableSize.width) * 2.0 - 1.0;
        const double ndcY = 1.0 - (point.y / drawableSize.height) * 2.0;
        return ViewerVertex{{static_cast<float>(ndcX), static_cast<float>(ndcY)}};
    };

    return {mapPoint(segment.start), mapPoint(segment.end)};
}

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
        _viewState = aaplcad::graphics::ViewState2d{};
        _commandQueue = [device newCommandQueue];
        _linePipelineState = [self buildLinePipelineForDevice:device];
        [self populateDemoDocument];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)drawInMTKView:(MTKView*)view {
    const double zoom = _viewState.zoom();
    const double tint = zoom < 1.0 ? 0.0 : (zoom - 1.0) / 4.0;
    self.clearColor = MTLClearColorMake(0.10 + tint * 0.2, 0.12, 0.16 + tint * 0.3, 1.0);

    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (drawable == nil || renderPassDescriptor == nil) {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    if (_linePipelineState != nil) {
        [encoder setRenderPipelineState:_linePipelineState];
        const auto drawList = aaplcad::graphics::buildDrawList2d(_document, _viewState, view.drawableSize.width, view.drawableSize.height);
        for (const auto& segment : drawList.lineSegments) {
            const auto vertices = [self clipSpaceVerticesForSegment:segment drawableSize:view.drawableSize];
            [encoder setVertexBytes:vertices.data() length:sizeof(ViewerVertex) * vertices.size() atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:2];
        }
    }

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
    _viewState.panByScreenDelta([event scrollingDeltaX], -[event scrollingDeltaY]);
    [self setNeedsDisplay:YES];
}

- (void)magnifyWithEvent:(NSEvent*)event {
    const NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    const double zoomFactor = 1.0 + [event magnification];
    _viewState.zoomAtScreenPoint(zoomFactor, location.x, location.y);
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer zoom updated");
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)event {
    const std::string message = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::buttonDown));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, message);
    [super mouseDown:event];
}

- (void)mouseDragged:(NSEvent*)event {
    const std::string message = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::move));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, message);
    _viewState.panByScreenDelta([event deltaX], -[event deltaY]);
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent*)event {
    if ([[event charactersIgnoringModifiers] isEqualToString:@"0"]) {
        _viewState.reset();
        aaplcad::core::logMessage(aaplcad::core::LogLevel::info, "viewer state reset");
        [self setNeedsDisplay:YES];
        return;
    }

    [super keyDown:event];
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
