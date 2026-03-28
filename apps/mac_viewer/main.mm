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
#include <sstream>
#include <memory>
#include <string>

struct ViewerVertex {
    float position[2];
};

struct ViewerColor {
    float rgba[4];
};

static constexpr double kSingleFingerTapMaxTravel = 0.02;

static NSPoint centroidForTouches(NSSet<NSTouch*>* touches) {
    if (touches.count == 0) {
        return NSMakePoint(0.0, 0.0);
    }

    double sumX = 0.0;
    double sumY = 0.0;
    for (NSTouch* touch in touches) {
        sumX += touch.normalizedPosition.x;
        sumY += touch.normalizedPosition.y;
    }

    return NSMakePoint(sumX / static_cast<double>(touches.count),
                       sumY / static_cast<double>(touches.count));
}

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

fragment float4 lineFragment(constant float4& color [[buffer(1)]]) {
    return color;
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
    aaplcad::core::ObjectId _selectedEntityId;
    bool _isDraggingView;
    bool _singleFingerTapCandidate;
    NSPoint _singleFingerTapStart;
    NSPoint _lastThreeFingerCentroid;
    bool _hasThreeFingerCentroid;
    NSTextField* _debugCoordinateLabel;
    NSTrackingArea* _trackingArea;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _linePipelineState;
}

- (void)handleSelectionEvent:(NSEvent*)event;
- (void)handlePanEvent:(NSEvent*)event;
- (void)handleMouseUpEvent:(NSEvent*)event;
- (BOOL)containsWindowPoint:(NSPoint)windowPoint;
- (void)handleIndirectTouchSelectionAtNormalizedPoint:(NSPoint)normalizedPoint;
- (NSPoint)currentRenderPointFromMouseLocation;
- (void)updateDebugCoordinateLabelWithRenderPoint:(NSPoint)renderPoint;
- (void)layoutDebugOverlay;
- (void)updateTrackingAreas;
- (void)clearDebugCoordinateLabel;
@end

@implementation AAPLViewerView

- (NSPoint)renderPointFromEvent:(NSEvent*)event {
    const NSPoint localPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    return NSMakePoint(localPoint.x, self.bounds.size.height - localPoint.y);
}

- (void)populateDemoDocument {
    const auto layerResult = _document.addLayer("demo");
    if (!layerResult.ok() && layerResult.error().code != "E_LAYER_EXISTS") {
        aaplcad::core::logMessage(aaplcad::core::LogLevel::error, "failed to create demo layer");
        return;
    }

    const aaplcad::geometry::Line2d houseLines[] = {
        {{220.0, 180.0}, {220.0, 360.0}},
        {{220.0, 360.0}, {420.0, 360.0}},
        {{420.0, 360.0}, {420.0, 180.0}},
        {{420.0, 180.0}, {220.0, 180.0}},
        {{220.0, 180.0}, {320.0, 90.0}},
        {{320.0, 90.0}, {420.0, 180.0}},
        {{290.0, 360.0}, {290.0, 260.0}},
        {{290.0, 260.0}, {350.0, 260.0}},
        {{350.0, 260.0}, {350.0, 360.0}},
        {{245.0, 230.0}, {285.0, 230.0}},
        {{285.0, 230.0}, {285.0, 280.0}},
        {{285.0, 280.0}, {245.0, 280.0}},
        {{245.0, 280.0}, {245.0, 230.0}},
        {{355.0, 230.0}, {395.0, 230.0}},
        {{395.0, 230.0}, {395.0, 280.0}},
        {{395.0, 280.0}, {355.0, 280.0}},
        {{355.0, 280.0}, {355.0, 230.0}},
    };

    for (const auto& line : houseLines) {
        auto entity = std::make_unique<aaplcad::database::LineEntity>(line);
        entity->setLayerName("demo");
        (void)_document.addEntity(std::move(entity));
    }
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

- (std::array<ViewerVertex, 2>)clipSpaceVerticesForSegment:(const aaplcad::graphics::LineSegment2d&)segment viewportSize:(CGSize)viewportSize {
    const auto mapPoint = ^ViewerVertex(aaplcad::geometry::Point2d point) {
        const double ndcX = (point.x / viewportSize.width) * 2.0 - 1.0;
        const double ndcY = 1.0 - (point.y / viewportSize.height) * 2.0;
        return ViewerVertex{{static_cast<float>(ndcX), static_cast<float>(ndcY)}};
    };

    return {mapPoint(segment.start), mapPoint(segment.end)};
}

- (aaplcad::graphics::DrawList2d)currentDrawList {
    return aaplcad::graphics::buildDrawList2d(_document, _viewState, self.bounds.size.width, self.bounds.size.height);
}

- (void)selectEntityAtViewPoint:(NSPoint)viewPoint {
    const auto drawList = [self currentDrawList];
    const double pickTolerance = 18.0;
    const auto hit = aaplcad::graphics::pickLineSegmentAtScreenPoint(drawList, {viewPoint.x, viewPoint.y}, pickTolerance);

    if (hit.has_value()) {
        _selectedEntityId = hit->entityId;
        std::ostringstream stream;
        stream << "viewer selected line entity id=" << hit->entityId.value()
               << " distance=" << hit->distance
               << " tolerance=" << pickTolerance;
        aaplcad::core::logMessage(aaplcad::core::LogLevel::info, stream.str());
    } else {
        _selectedEntityId = aaplcad::core::ObjectId{};
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer selection cleared");
    }
}

- (NSPoint)currentRenderPointFromMouseLocation {
    const NSPoint windowPoint = [self.window mouseLocationOutsideOfEventStream];
    const NSPoint localPoint = [self convertPoint:windowPoint fromView:nil];
    return NSMakePoint(localPoint.x, self.bounds.size.height - localPoint.y);
}

- (void)handleSelectionEvent:(NSEvent*)event {
    [[self window] makeFirstResponder:self];
    _isDraggingView = YES;

    const std::string eventDescription = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::buttonDown));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, eventDescription);

    const NSPoint location = [self renderPointFromEvent:event];
    std::ostringstream stream;
    stream << "viewer click at (" << location.x << ", " << location.y << ")";
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, stream.str());

    [self selectEntityAtViewPoint:location];
    [self setNeedsDisplay:YES];
}

- (void)handlePanEvent:(NSEvent*)event {
    if (!_isDraggingView) {
        return;
    }

    [[self window] makeFirstResponder:self];

    const std::string eventDescription = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::move));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, eventDescription);

    _viewState.panByScreenDelta([event deltaX], -[event deltaY]);
    [self setNeedsDisplay:YES];
}

- (void)handleMouseUpEvent:(NSEvent*)event {
    (void)event;
    _isDraggingView = NO;
}

- (BOOL)containsWindowPoint:(NSPoint)windowPoint {
    const NSPoint localPoint = [self convertPoint:windowPoint fromView:nil];
    return NSPointInRect(localPoint, self.bounds);
}

- (void)handleIndirectTouchSelectionAtNormalizedPoint:(NSPoint)normalizedPoint {
    NSPoint renderPoint = [self currentRenderPointFromMouseLocation];
    const NSPoint localMousePoint = NSMakePoint(renderPoint.x, self.bounds.size.height - renderPoint.y);
    if (!NSPointInRect(localMousePoint, self.bounds)) {
        renderPoint = NSMakePoint(normalizedPoint.x * self.bounds.size.width,
                                  normalizedPoint.y * self.bounds.size.height);
    }

    std::ostringstream stream;
    stream << "viewer indirect touch at (" << renderPoint.x << ", " << renderPoint.y << ")";
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, stream.str());

    [self selectEntityAtViewPoint:renderPoint];
    [self setNeedsDisplay:YES];
}

- (void)updateDebugCoordinateLabelWithRenderPoint:(NSPoint)renderPoint {
    if (_debugCoordinateLabel == nil) {
        return;
    }

    const auto worldPoint = _viewState.screenToWorld({renderPoint.x, renderPoint.y});
    _debugCoordinateLabel.stringValue = [NSString stringWithFormat:@"screen: (%.1f, %.1f)\nworld:  (%.2f, %.2f)",
                                                                       renderPoint.x,
                                                                       renderPoint.y,
                                                                       worldPoint.x,
                                                                       worldPoint.y];
}

- (void)clearDebugCoordinateLabel {
    if (_debugCoordinateLabel == nil) {
        return;
    }

    _debugCoordinateLabel.stringValue = @"screen: (--, --)\nworld:  (--, --)";
}

- (void)layoutDebugOverlay {
    if (_debugCoordinateLabel == nil) {
        return;
    }

    const CGFloat width = 210.0;
    const CGFloat height = 38.0;
    const CGFloat margin = 12.0;
    _debugCoordinateLabel.frame = NSMakeRect(NSWidth(self.bounds) - width - margin,
                                             NSHeight(self.bounds) - height - margin,
                                             width,
                                             height);
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
        self.wantsRestingTouches = YES;
        self.allowedTouchTypes = NSTouchTypeMaskIndirect;
        _viewState = aaplcad::graphics::ViewState2d{};
        _selectedEntityId = aaplcad::core::ObjectId{};
        _isDraggingView = NO;
        _singleFingerTapCandidate = NO;
        _singleFingerTapStart = NSMakePoint(0.0, 0.0);
        _lastThreeFingerCentroid = NSMakePoint(0.0, 0.0);
        _hasThreeFingerCentroid = NO;
        _debugCoordinateLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
        _debugCoordinateLabel.editable = NO;
        _debugCoordinateLabel.bezeled = NO;
        _debugCoordinateLabel.drawsBackground = NO;
        _debugCoordinateLabel.selectable = NO;
        _debugCoordinateLabel.alignment = NSTextAlignmentRight;
        _debugCoordinateLabel.textColor = [NSColor colorWithWhite:0.92 alpha:0.95];
        _debugCoordinateLabel.font = [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightRegular];
        _debugCoordinateLabel.usesSingleLineMode = NO;
        _debugCoordinateLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _debugCoordinateLabel.stringValue = @"screen: (--, --)\nworld:  (--, --)";
        [self addSubview:_debugCoordinateLabel];
        [self layoutDebugOverlay];
        _trackingArea = nil;
        _commandQueue = [device newCommandQueue];
        _linePipelineState = [self buildLinePipelineForDevice:device];
        [self populateDemoDocument];
    }
    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    self.window.acceptsMouseMovedEvents = YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
    (void)event;
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
        const auto drawList = [self currentDrawList];
        const CGSize viewportSize = self.bounds.size;
        for (const auto& segment : drawList.lineSegments) {
            const auto vertices = [self clipSpaceVerticesForSegment:segment viewportSize:viewportSize];
            const bool isSelected = segment.entityId == _selectedEntityId;
            const ViewerColor color = isSelected
                ? ViewerColor{{1.0f, 0.35f, 0.25f, 1.0f}}
                : ViewerColor{{0.89f, 0.77f, 0.27f, 1.0f}};

            if (isSelected) {
                static constexpr std::array<ViewerVertex, 2> kOffsets[] = {
                    std::array<ViewerVertex, 2>{ViewerVertex{{0.0f, 0.0f}}, ViewerVertex{{0.0f, 0.0f}}},
                    std::array<ViewerVertex, 2>{ViewerVertex{{-0.004f, 0.0f}}, ViewerVertex{{-0.004f, 0.0f}}},
                    std::array<ViewerVertex, 2>{ViewerVertex{{0.004f, 0.0f}}, ViewerVertex{{0.004f, 0.0f}}},
                    std::array<ViewerVertex, 2>{ViewerVertex{{0.0f, -0.004f}}, ViewerVertex{{0.0f, -0.004f}}},
                    std::array<ViewerVertex, 2>{ViewerVertex{{0.0f, 0.004f}}, ViewerVertex{{0.0f, 0.004f}}},
                };

                const ViewerColor highlightColor{{1.0f, 0.15f, 0.15f, 1.0f}};
                for (const auto& offset : kOffsets) {
                    std::array<ViewerVertex, 2> highlightedVertices = vertices;
                    highlightedVertices[0].position[0] += offset[0].position[0];
                    highlightedVertices[0].position[1] += offset[0].position[1];
                    highlightedVertices[1].position[0] += offset[1].position[0];
                    highlightedVertices[1].position[1] += offset[1].position[1];
                    [encoder setVertexBytes:highlightedVertices.data() length:sizeof(ViewerVertex) * highlightedVertices.size() atIndex:0];
                    [encoder setFragmentBytes:&highlightColor length:sizeof(highlightColor) atIndex:1];
                    [encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:2];
                }
            }

            [encoder setVertexBytes:vertices.data() length:sizeof(ViewerVertex) * vertices.size() atIndex:0];
            [encoder setFragmentBytes:&color length:sizeof(color) atIndex:1];
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
    [self layoutDebugOverlay];
}

- (void)updateTrackingAreas {
    if (_trackingArea != nil) {
        [self removeTrackingArea:_trackingArea];
    }

    const NSTrackingAreaOptions options = NSTrackingMouseMoved |
        NSTrackingMouseEnteredAndExited |
        NSTrackingActiveInKeyWindow |
        NSTrackingInVisibleRect;
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:options
                                                   owner:self
                                                userInfo:nil];
    [self addTrackingArea:_trackingArea];
    [super updateTrackingAreas];
}

- (void)scrollWheel:(NSEvent*)event {
    const std::string message = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::scroll));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, message);
    const double deltaY = [event hasPreciseScrollingDeltas] ? [event scrollingDeltaY] : -[event scrollingDeltaY];
    _viewState.panByScreenDelta([event scrollingDeltaX], deltaY);
    [self setNeedsDisplay:YES];
}

- (void)magnifyWithEvent:(NSEvent*)event {
    const NSPoint location = [self renderPointFromEvent:event];
    const double zoomFactor = 1.0 + [event magnification];
    _viewState.zoomAtScreenPoint(zoomFactor, location.x, location.y);
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer zoom updated");
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
    [self handleSelectionEvent:event];
}

- (void)mouseDragged:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
    [self handlePanEvent:event];
}

- (void)mouseMoved:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
}

- (void)mouseExited:(NSEvent*)event {
    (void)event;
    [self clearDebugCoordinateLabel];
}

- (void)leftMouseDown:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
    [self handleSelectionEvent:event];
}

- (void)leftMouseDragged:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
    [self handlePanEvent:event];
}

- (void)mouseUp:(NSEvent*)event {
    [self handleMouseUpEvent:event];
}

- (void)leftMouseUp:(NSEvent*)event {
    [self handleMouseUpEvent:event];
}

- (void)touchesBeganWithEvent:(NSEvent*)event {
    [super touchesBeganWithEvent:event];

    NSSet<NSTouch*>* activeTouches = [event touchesMatchingPhase:NSTouchPhaseTouching | NSTouchPhaseBegan inView:self];
    if (activeTouches.count == 1) {
        _singleFingerTapCandidate = YES;
        _singleFingerTapStart = centroidForTouches(activeTouches);
    } else {
        _singleFingerTapCandidate = NO;
    }

    if (activeTouches.count == 3) {
        _hasThreeFingerCentroid = YES;
        _lastThreeFingerCentroid = centroidForTouches(activeTouches);
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer three-finger gesture began");
    }
}

- (void)touchesMovedWithEvent:(NSEvent*)event {
    [super touchesMovedWithEvent:event];

    NSSet<NSTouch*>* activeTouches = [event touchesMatchingPhase:NSTouchPhaseTouching | NSTouchPhaseStationary inView:self];
    if (activeTouches.count == 1 && _singleFingerTapCandidate) {
        const NSPoint centroid = centroidForTouches(activeTouches);
        const double deltaX = centroid.x - _singleFingerTapStart.x;
        const double deltaY = centroid.y - _singleFingerTapStart.y;
        if ((deltaX * deltaX + deltaY * deltaY) > (kSingleFingerTapMaxTravel * kSingleFingerTapMaxTravel)) {
            _singleFingerTapCandidate = NO;
        }
    }

    if (activeTouches.count == 3) {
        const NSPoint centroid = centroidForTouches(activeTouches);
        if (_hasThreeFingerCentroid) {
            const double deltaX = (centroid.x - _lastThreeFingerCentroid.x) * self.bounds.size.width;
            const double deltaY = (centroid.y - _lastThreeFingerCentroid.y) * self.bounds.size.height;
            _viewState.panByScreenDelta(deltaX, deltaY);
            [self setNeedsDisplay:YES];
        }

        _lastThreeFingerCentroid = centroid;
        _hasThreeFingerCentroid = YES;
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer three-finger pan updated");
        return;
    }

    _hasThreeFingerCentroid = NO;
}

- (void)touchesEndedWithEvent:(NSEvent*)event {
    [super touchesEndedWithEvent:event];

    NSSet<NSTouch*>* endingTouches = [event touchesMatchingPhase:NSTouchPhaseEnded inView:self];
    if (_singleFingerTapCandidate && endingTouches.count == 1) {
        [self handleIndirectTouchSelectionAtNormalizedPoint:centroidForTouches(endingTouches)];
    }

    _singleFingerTapCandidate = NO;
    _hasThreeFingerCentroid = NO;
}

- (void)touchesCancelledWithEvent:(NSEvent*)event {
    [super touchesCancelledWithEvent:event];
    _singleFingerTapCandidate = NO;
    _hasThreeFingerCentroid = NO;
}

- (void)keyDown:(NSEvent*)event {
    if ([[event charactersIgnoringModifiers] isEqualToString:@"0"]) {
        _viewState.reset();
        _selectedEntityId = aaplcad::core::ObjectId{};
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
        [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown |
                                                     NSEventMaskLeftMouseDragged |
                                                     NSEventMaskLeftMouseUp)
                                             handler:^NSEvent* _Nullable(NSEvent* event) {
            if (![metalView containsWindowPoint:[event locationInWindow]]) {
                return event;
            }

            switch ([event type]) {
            case NSEventTypeLeftMouseDown:
                [metalView handleSelectionEvent:event];
                return nil;
            case NSEventTypeLeftMouseDragged:
                [metalView handlePanEvent:event];
                return nil;
            case NSEventTypeLeftMouseUp:
                [metalView handleMouseUpEvent:event];
                return nil;
            default:
                return event;
            }
        }];
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
