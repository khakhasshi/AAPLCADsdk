#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "aaplcad/aaplcad.h"
#include "aaplcad/core/log.h"
#include "aaplcad/database/document.h"
#include "aaplcad/database/line_entity.h"
#include "aaplcad/geometry/line2d.h"
#include "aaplcad/graphics/draw_list_2d.h"
#include "aaplcad/graphics/selection_state_2d.h"
#include "aaplcad/graphics/view_interaction_state_2d.h"
#include "aaplcad/graphics/view_state_2d.h"
#include "aaplcad/platform/input_event.h"
#include "aaplcad/platform/platform.h"

#include <memory>
#include <array>
#include <sstream>
#include <string>

struct ViewerVertex {
    float position[2];
};

struct ViewerColor {
    float rgba[4];
};

static constexpr double kBoxSelectionMinSize = 4.0;

static aaplcad::geometry::Point2d centroidForTouches(NSSet<NSTouch*>* touches) {
    if (touches.count == 0) {
        return {0.0, 0.0};
    }

    double sumX = 0.0;
    double sumY = 0.0;
    for (NSTouch* touch in touches) {
        sumX += touch.normalizedPosition.x;
        sumY += touch.normalizedPosition.y;
    }

    return {
        sumX / static_cast<double>(touches.count),
        sumY / static_cast<double>(touches.count),
    };
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
    aaplcad::graphics::ViewInteractionState2d _interactionState;
    aaplcad::graphics::SelectionState2d _selectionState;
    aaplcad::database::Document _document;
    bool _isBoxSelecting;
    bool _boxSelectionUsesTouch;
    NSPoint _boxSelectionStart;
    NSPoint _boxSelectionCurrent;
    NSTextField* _debugCoordinateLabel;
    NSTrackingArea* _trackingArea;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _linePipelineState;
}

- (void)handleSelectionEvent:(NSEvent*)event;
- (void)handleBoxSelectionDragEvent:(NSEvent*)event;
- (void)handlePanEvent:(NSEvent*)event;
- (void)handleMouseUpEvent:(NSEvent*)event;
- (BOOL)containsWindowPoint:(NSPoint)windowPoint;
- (void)handleIndirectTouchSelectionAtNormalizedPoint:(NSPoint)normalizedPoint;
- (NSPoint)currentRenderPointFromMouseLocation;
- (void)updateDebugCoordinateLabelWithRenderPoint:(NSPoint)renderPoint;
- (void)layoutDebugOverlay;
- (void)updateTrackingAreas;
- (void)clearDebugCoordinateLabel;
- (BOOL)isBoxSelectionModifierActive:(NSEvent*)event;
- (BOOL)shouldUseTouchBoxSelection:(NSEvent*)event touchCount:(NSUInteger)touchCount;
- (aaplcad::geometry::Extents2d)currentBoxSelectionRect;
- (void)applyBoxSelection;
- (NSPoint)renderPointFromNormalizedPoint:(aaplcad::geometry::Point2d)normalizedPoint;
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
        (void)_selectionState.applyHit(hit);
        std::ostringstream stream;
        stream << "viewer selected line entity id=" << hit->entityId.value()
               << " distance=" << hit->distance
               << " tolerance=" << pickTolerance;
        aaplcad::core::logMessage(aaplcad::core::LogLevel::info, stream.str());
    } else {
        if (_selectionState.applyHit(hit)) {
            aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer selection cleared");
        }
    }
}

- (BOOL)isBoxSelectionModifierActive:(NSEvent*)event {
    return (mapModifiers([event modifierFlags]) & aaplcad::platform::modifierShift) != 0;
}

- (BOOL)shouldUseTouchBoxSelection:(NSEvent*)event touchCount:(NSUInteger)touchCount {
    return touchCount == 3 && [self isBoxSelectionModifierActive:event];
}

- (NSPoint)renderPointFromNormalizedPoint:(aaplcad::geometry::Point2d)normalizedPoint {
    return NSMakePoint(normalizedPoint.x * self.bounds.size.width,
                       normalizedPoint.y * self.bounds.size.height);
}

- (aaplcad::geometry::Extents2d)currentBoxSelectionRect {
    return {
        {std::min(_boxSelectionStart.x, _boxSelectionCurrent.x), std::min(_boxSelectionStart.y, _boxSelectionCurrent.y)},
        {std::max(_boxSelectionStart.x, _boxSelectionCurrent.x), std::max(_boxSelectionStart.y, _boxSelectionCurrent.y)},
    };
}

- (void)applyBoxSelection {
    const auto rect = [self currentBoxSelectionRect];
    if (rect.width() < kBoxSelectionMinSize && rect.height() < kBoxSelectionMinSize) {
        [self selectEntityAtViewPoint:_boxSelectionCurrent];
        return;
    }

    const auto drawList = [self currentDrawList];
    const auto entityIds = aaplcad::graphics::pickLineSegmentsInScreenRect(drawList, rect);
    const bool changed = _selectionState.replaceWith(entityIds);
    std::ostringstream stream;
    stream << "viewer box selected " << entityIds.size() << " entities";
    aaplcad::core::logMessage(changed ? aaplcad::core::LogLevel::info : aaplcad::core::LogLevel::debug, stream.str());
}

- (NSPoint)currentRenderPointFromMouseLocation {
    const NSPoint windowPoint = [self.window mouseLocationOutsideOfEventStream];
    const NSPoint localPoint = [self convertPoint:windowPoint fromView:nil];
    return NSMakePoint(localPoint.x, self.bounds.size.height - localPoint.y);
}

- (void)handleSelectionEvent:(NSEvent*)event {
    [[self window] makeFirstResponder:self];

    const NSPoint location = [self renderPointFromEvent:event];
    if ([self isBoxSelectionModifierActive:event]) {
        _isBoxSelecting = YES;
        _boxSelectionUsesTouch = NO;
        _boxSelectionStart = location;
        _boxSelectionCurrent = location;
        [self setNeedsDisplay:YES];
        return;
    }

    _interactionState.beginPointerDrag();

    const std::string eventDescription = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::buttonDown));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, eventDescription);

    std::ostringstream stream;
    stream << "viewer click at (" << location.x << ", " << location.y << ")";
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, stream.str());

    [self selectEntityAtViewPoint:location];
    [self setNeedsDisplay:YES];
}

- (void)handleBoxSelectionDragEvent:(NSEvent*)event {
    if (!_isBoxSelecting) {
        return;
    }

    _boxSelectionCurrent = [self renderPointFromEvent:event];
    [self setNeedsDisplay:YES];
}

- (void)handlePanEvent:(NSEvent*)event {
    if (_isBoxSelecting) {
        [self handleBoxSelectionDragEvent:event];
        return;
    }

    if (!_interactionState.isPointerDragging()) {
        return;
    }

    [[self window] makeFirstResponder:self];

    const std::string eventDescription = aaplcad::platform::describe(makePointerEvent(event, aaplcad::platform::InputAction::move));
    aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, eventDescription);

    if (_interactionState.applyPointerPan(_viewState, [event deltaX], -[event deltaY])) {
        [self setNeedsDisplay:YES];
    }
}

- (void)handleMouseUpEvent:(NSEvent*)event {
    if (_isBoxSelecting) {
        _boxSelectionCurrent = [self renderPointFromEvent:event];
        [self applyBoxSelection];
        _isBoxSelecting = NO;
        _boxSelectionUsesTouch = NO;
        [self setNeedsDisplay:YES];
    }

    _interactionState.endPointerDrag();
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
        _isBoxSelecting = NO;
        _boxSelectionUsesTouch = NO;
        _boxSelectionStart = NSMakePoint(0.0, 0.0);
        _boxSelectionCurrent = NSMakePoint(0.0, 0.0);
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
            const bool isSelected = _selectionState.isSelected(segment.entityId);
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

        if (_isBoxSelecting) {
            const auto rect = [self currentBoxSelectionRect];
            if (rect.width() > 0.0 || rect.height() > 0.0) {
                const aaplcad::graphics::LineSegment2d boxSegments[] = {
                    {{}, {rect.min.x, rect.min.y}, {rect.max.x, rect.min.y}},
                    {{}, {rect.max.x, rect.min.y}, {rect.max.x, rect.max.y}},
                    {{}, {rect.max.x, rect.max.y}, {rect.min.x, rect.max.y}},
                    {{}, {rect.min.x, rect.max.y}, {rect.min.x, rect.min.y}},
                };
                const ViewerColor boxColor{{0.45f, 0.75f, 1.0f, 1.0f}};
                for (const auto& boxSegment : boxSegments) {
                    const auto vertices = [self clipSpaceVerticesForSegment:boxSegment viewportSize:viewportSize];
                    [encoder setVertexBytes:vertices.data() length:sizeof(ViewerVertex) * vertices.size() atIndex:0];
                    [encoder setFragmentBytes:&boxColor length:sizeof(boxColor) atIndex:1];
                    [encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:2];
                }
            }
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
    if (_interactionState.applyMagnify(_viewState, [event magnification], {location.x, location.y})) {
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer zoom updated");
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
    [self handleSelectionEvent:event];
}

- (void)mouseDragged:(NSEvent*)event {
    [self updateDebugCoordinateLabelWithRenderPoint:[self renderPointFromEvent:event]];
    if (_isBoxSelecting) {
        [self handleBoxSelectionDragEvent:event];
        return;
    }

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
    if (_isBoxSelecting) {
        [self handleBoxSelectionDragEvent:event];
        return;
    }

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
    if ([self shouldUseTouchBoxSelection:event touchCount:activeTouches.count]) {
        const auto centroid = centroidForTouches(activeTouches);
        _interactionState.cancelTouchSequence();
        _isBoxSelecting = YES;
        _boxSelectionUsesTouch = YES;
        _boxSelectionStart = [self renderPointFromNormalizedPoint:centroid];
        _boxSelectionCurrent = _boxSelectionStart;
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer touch box-selection began");
        [self setNeedsDisplay:YES];
        return;
    }

    _interactionState.beginTouchSequence(activeTouches.count, centroidForTouches(activeTouches));
    if (activeTouches.count == 3) {
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer three-finger gesture began");
    }
}

- (void)touchesMovedWithEvent:(NSEvent*)event {
    [super touchesMovedWithEvent:event];

    NSSet<NSTouch*>* activeTouches = [event touchesMatchingPhase:NSTouchPhaseTouching | NSTouchPhaseStationary inView:self];
    if (_isBoxSelecting && _boxSelectionUsesTouch) {
        _boxSelectionCurrent = [self renderPointFromNormalizedPoint:centroidForTouches(activeTouches)];
        [self setNeedsDisplay:YES];
        return;
    }

    if (_interactionState.updateTouchSequence(_viewState,
                                              activeTouches.count,
                                              centroidForTouches(activeTouches),
                                              self.bounds.size.width,
                                              self.bounds.size.height)) {
        [self setNeedsDisplay:YES];
    }

    if (activeTouches.count == 3) {
        aaplcad::core::logMessage(aaplcad::core::LogLevel::debug, "viewer three-finger pan updated");
    }
}

- (void)touchesEndedWithEvent:(NSEvent*)event {
    [super touchesEndedWithEvent:event];

    if (_isBoxSelecting && _boxSelectionUsesTouch) {
        NSSet<NSTouch*>* endingTouches = [event touchesMatchingPhase:NSTouchPhaseEnded inView:self];
        _boxSelectionCurrent = [self renderPointFromNormalizedPoint:centroidForTouches(endingTouches.count > 0 ? endingTouches : [event touchesMatchingPhase:NSTouchPhaseAny inView:self])];
        [self applyBoxSelection];
        _isBoxSelecting = NO;
        _boxSelectionUsesTouch = NO;
        [self setNeedsDisplay:YES];
        return;
    }

    NSSet<NSTouch*>* endingTouches = [event touchesMatchingPhase:NSTouchPhaseEnded inView:self];
    const auto normalizedPoint = _interactionState.endTouchSequence(endingTouches.count, centroidForTouches(endingTouches));
    if (normalizedPoint.has_value()) {
        [self handleIndirectTouchSelectionAtNormalizedPoint:NSMakePoint(normalizedPoint->x, normalizedPoint->y)];
    }
}

- (void)touchesCancelledWithEvent:(NSEvent*)event {
    [super touchesCancelledWithEvent:event];
    _isBoxSelecting = NO;
    _boxSelectionUsesTouch = NO;
    _interactionState.cancelTouchSequence();
}

- (void)keyDown:(NSEvent*)event {
    if ([[event charactersIgnoringModifiers] isEqualToString:@"0"]) {
        _viewState.reset();
        _selectionState.clear();
        _isBoxSelecting = NO;
        _boxSelectionUsesTouch = NO;
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
