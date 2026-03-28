#include "aaplcad/core/object_id.h"
#include "aaplcad/core/result.h"
#include "aaplcad/core/vector2d.h"
#include "aaplcad/database/document.h"
#include "aaplcad/database/line_entity.h"
#include "aaplcad/geometry/circle2d.h"
#include "aaplcad/geometry/line2d.h"
#include "aaplcad/geometry/point2d.h"
#include "aaplcad/graphics/draw_list_2d.h"
#include "aaplcad/graphics/view_interaction_state_2d.h"
#include "aaplcad/graphics/view_state_2d.h"
#include "aaplcad/platform/input_event.h"
#include "aaplcad/platform/platform.h"

#include <cstdlib>
#include <cmath>
#include <iostream>

namespace {

void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "test failure: " << message << '\n';
        std::exit(1);
    }
}

void requireNear(double actual, double expected, double tolerance, const char* message) {
    require(std::abs(actual - expected) <= tolerance, message);
}

}  // namespace

int main() {
    const aaplcad::core::ObjectId invalidId;
    const aaplcad::core::ObjectId validId{42};
    require(!invalidId.isValid(), "default object id should be invalid");
    require(validId.isValid(), "explicit object id should be valid");
    require(validId.value() == 42, "object id should preserve numeric value");

    const aaplcad::core::Result<int> okResult{7};
    require(okResult.ok(), "value result should be ok");
    require(okResult.value() == 7, "value result should expose stored value");

    const aaplcad::core::Result<void> errorResult{{"E_PHASE1", "phase 1 placeholder error"}};
    require(!errorResult.ok(), "error result should not be ok");
    require(errorResult.error().code == "E_PHASE1", "error result should expose error code");

    const auto point = aaplcad::core::Vector2d{1.0, 2.0}.translated(3.0, -1.0);
    require(point.x == 4.0 && point.y == 1.0, "vector translation should work");

    const auto movedPoint = aaplcad::geometry::Point2d{2.0, 5.0}.translated(-1.0, 4.0);
    require(movedPoint.x == 1.0 && movedPoint.y == 9.0, "point translation should work");

    const aaplcad::geometry::Line2d line{{0.0, 1.0}, {4.0, 3.0}};
    const auto lineExtents = line.extents();
    require(lineExtents.width() == 4.0, "line extents should compute width");
    require(lineExtents.height() == 2.0, "line extents should compute height");

    const aaplcad::geometry::Circle2d circle{{3.0, 3.0}, 2.0};
    const auto circleExtents = circle.extents();
    require(circleExtents.min.x == 1.0 && circleExtents.max.y == 5.0, "circle extents should reflect radius");

    aaplcad::database::Document document;
    require(document.layerCount() == 1, "document should create default layer");

    const auto layerResult = document.addLayer("geometry");
    require(layerResult.ok(), "adding a new layer should succeed");
    require(document.layerCount() == 2, "layer count should increase after insertion");

    auto entity = std::make_unique<aaplcad::database::LineEntity>(line);
    entity->setLayerName("geometry");

    const auto entityResult = document.addEntity(std::move(entity));
    require(entityResult.ok(), "adding an entity should succeed when layer exists");
    require(document.entityCount() == 1, "entity count should increase after insertion");
    require(document.findEntity(entityResult.value()) != nullptr, "document should find stored entity by id");

    const auto transaction = document.beginTransaction();
    require(transaction.isActive(), "new transaction should be active");

    const aaplcad::platform::PointerEvent pointerEvent{
        aaplcad::platform::InputDevice::trackpad,
        aaplcad::platform::InputAction::scroll,
        10.0,
        20.0,
        0.5,
        -1.5,
        aaplcad::platform::modifierShift | aaplcad::platform::modifierCommand,
    };
    const auto description = aaplcad::platform::describe(pointerEvent);
    require(description.find("trackpad:scroll") != std::string::npos, "pointer event description should include device and action");

    aaplcad::graphics::ViewState2d viewState;
    viewState.panByScreenDelta(20.0, -10.0);
    require(viewState.panX() == 20.0 && viewState.panY() == -10.0, "view state should update pan offsets");

    const auto anchorBefore = viewState.screenToWorld({100.0, 100.0});
    viewState.zoomAtScreenPoint(1.5, 100.0, 100.0);
    require(viewState.zoom() > 1.0, "view state should increase zoom after zoomAtScreenPoint");
    const auto anchorAfter = viewState.screenToWorld({100.0, 100.0});
    require(anchorBefore.x == anchorAfter.x && anchorBefore.y == anchorAfter.y, "zoom anchor should stay stable in world space");

    const auto screenPoint = viewState.worldToScreen({4.0, 6.0});
    const auto worldPoint = viewState.screenToWorld(screenPoint);
    require(worldPoint.x == 4.0 && worldPoint.y == 6.0, "world/screen transforms should round-trip");

    aaplcad::graphics::ViewState2d drawListViewState;
    const auto drawList = aaplcad::graphics::buildDrawList2d(document, drawListViewState, 500.0, 500.0);
    require(drawList.lineSegments.size() == 1, "draw list should include visible line entities");
    require(drawList.lineSegments.front().entityId == entityResult.value(), "draw list should preserve entity id for picking");
    require(drawList.lineSegments.front().start.x == 0.0, "draw list should transform line start x");

    const auto pickHit = aaplcad::graphics::pickLineSegmentAtScreenPoint(drawList, {2.0, 2.0}, 4.0);
    require(pickHit.has_value(), "picking should hit the visible line when within tolerance");
    require(pickHit->entityId == entityResult.value(), "picking should return the matching entity id");

    const auto missHit = aaplcad::graphics::pickLineSegmentAtScreenPoint(drawList, {200.0, 200.0}, 4.0);
    require(!missHit.has_value(), "picking should miss when no line is within tolerance");

    aaplcad::graphics::ViewState2d farAwayViewState;
    farAwayViewState.panByScreenDelta(-1000.0, -1000.0);
    const auto culledDrawList = aaplcad::graphics::buildDrawList2d(document, farAwayViewState, 100.0, 100.0);
    require(culledDrawList.lineSegments.empty(), "draw list should cull off-screen geometry");

    aaplcad::graphics::ViewInteractionState2d interactionState;
    aaplcad::graphics::ViewState2d pointerDragViewState;
    require(!interactionState.isPointerDragging(), "pointer dragging should start disabled");
    require(!interactionState.applyPointerPan(pointerDragViewState, 3.0, 4.0), "pointer pan should be ignored when dragging is inactive");
    interactionState.beginPointerDrag();
    require(interactionState.isPointerDragging(), "pointer dragging should activate after beginPointerDrag");
    require(interactionState.applyPointerPan(pointerDragViewState, 5.0, -2.0), "pointer pan should apply while dragging is active");
    requireNear(pointerDragViewState.panX(), 5.0, 1e-9, "pointer pan should update x offset");
    requireNear(pointerDragViewState.panY(), -2.0, 1e-9, "pointer pan should update y offset");
    interactionState.endPointerDrag();
    require(!interactionState.isPointerDragging(), "pointer dragging should deactivate after endPointerDrag");

    aaplcad::graphics::ViewState2d touchViewState;
    interactionState.beginTouchSequence(1, {0.25, 0.50});
    interactionState.updateTouchSequence(touchViewState, 1, {0.255, 0.505}, 800.0, 600.0);
    const auto tapPoint = interactionState.endTouchSequence(1, {0.255, 0.505});
    require(tapPoint.has_value(), "small single-finger motion should remain a tap candidate");

    interactionState.beginTouchSequence(1, {0.10, 0.10});
    interactionState.updateTouchSequence(touchViewState, 1, {0.25, 0.25}, 800.0, 600.0);
    const auto cancelledTap = interactionState.endTouchSequence(1, {0.25, 0.25});
    require(!cancelledTap.has_value(), "large single-finger motion should cancel tap selection");

    interactionState.beginTouchSequence(3, {0.50, 0.50});
    require(!interactionState.updateTouchSequence(touchViewState, 3, {0.50, 0.50}, 800.0, 600.0), "initial three-finger update should only seed centroid state");
    require(interactionState.updateTouchSequence(touchViewState, 3, {0.60, 0.55}, 800.0, 600.0), "subsequent three-finger update should pan the view");
    requireNear(touchViewState.panX(), 80.0, 1e-9, "three-finger pan should scale normalized x delta into screen-space pan");
    requireNear(touchViewState.panY(), 30.0, 1e-9, "three-finger pan should scale normalized y delta into screen-space pan");

    const auto worldAnchorBeforeMagnify = touchViewState.screenToWorld({400.0, 300.0});
    require(interactionState.applyMagnify(touchViewState, 0.25, {400.0, 300.0}), "positive magnification should zoom the view");
    const auto worldAnchorAfterMagnify = touchViewState.screenToWorld({400.0, 300.0});
    require(worldAnchorBeforeMagnify.x == worldAnchorAfterMagnify.x &&
                worldAnchorBeforeMagnify.y == worldAnchorAfterMagnify.y,
            "magnify should keep the zoom anchor stable in world space");
    require(!interactionState.applyMagnify(touchViewState, -1.1, {400.0, 300.0}), "invalid negative magnification should be rejected");

    const auto platform = aaplcad::platform::currentPlatform();
    require(!platform.operatingSystem.empty(), "platform info should expose operating system");

    std::cout << "aaplcad_tests passed\n";
    return 0;
}
