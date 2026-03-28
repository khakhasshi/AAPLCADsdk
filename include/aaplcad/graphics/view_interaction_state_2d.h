#pragma once

#include "aaplcad/geometry/point2d.h"
#include "aaplcad/graphics/view_state_2d.h"

#include <cstddef>
#include <optional>

namespace aaplcad::graphics {

class ViewInteractionState2d {
public:
    [[nodiscard]] bool isPointerDragging() const noexcept {
        return isPointerDragging_;
    }

    void beginPointerDrag() noexcept {
        isPointerDragging_ = true;
    }

    void endPointerDrag() noexcept {
        isPointerDragging_ = false;
    }

    bool applyPointerPan(ViewState2d& viewState, double deltaX, double deltaY) noexcept {
        if (!isPointerDragging_) {
            return false;
        }

        viewState.panByScreenDelta(deltaX, deltaY);
        return true;
    }

    void beginTouchSequence(std::size_t touchCount, geometry::Point2d centroidNormalized) noexcept {
        if (touchCount == 1) {
            singleFingerTapCandidate_ = true;
            singleFingerTapStart_ = centroidNormalized;
        } else {
            singleFingerTapCandidate_ = false;
        }

        if (touchCount == 3) {
            hasThreeFingerCentroid_ = true;
            lastThreeFingerCentroid_ = centroidNormalized;
        } else {
            hasThreeFingerCentroid_ = false;
        }
    }

    bool updateTouchSequence(ViewState2d& viewState,
                             std::size_t touchCount,
                             geometry::Point2d centroidNormalized,
                             double viewportWidth,
                             double viewportHeight) noexcept {
        if (touchCount == 1 && singleFingerTapCandidate_) {
            const double deltaX = centroidNormalized.x - singleFingerTapStart_.x;
            const double deltaY = centroidNormalized.y - singleFingerTapStart_.y;
            if ((deltaX * deltaX + deltaY * deltaY) > (kSingleFingerTapMaxTravel * kSingleFingerTapMaxTravel)) {
                singleFingerTapCandidate_ = false;
            }
        }

        if (touchCount != 3) {
            hasThreeFingerCentroid_ = false;
            return false;
        }

        bool didPan = false;
        if (hasThreeFingerCentroid_) {
            const double deltaX = (centroidNormalized.x - lastThreeFingerCentroid_.x) * viewportWidth;
            const double deltaY = (centroidNormalized.y - lastThreeFingerCentroid_.y) * viewportHeight;
            if (deltaX != 0.0 || deltaY != 0.0) {
                viewState.panByScreenDelta(deltaX, deltaY);
                didPan = true;
            }
        }

        lastThreeFingerCentroid_ = centroidNormalized;
        hasThreeFingerCentroid_ = true;
        return didPan;
    }

    [[nodiscard]] std::optional<geometry::Point2d> endTouchSequence(std::size_t endingTouchCount,
                                                                     geometry::Point2d centroidNormalized) noexcept {
        std::optional<geometry::Point2d> selectionPoint;
        if (singleFingerTapCandidate_ && endingTouchCount == 1) {
            selectionPoint = centroidNormalized;
        }

        cancelTouchSequence();
        return selectionPoint;
    }

    void cancelTouchSequence() noexcept {
        singleFingerTapCandidate_ = false;
        hasThreeFingerCentroid_ = false;
    }

    bool applyMagnify(ViewState2d& viewState, double magnification, geometry::Point2d anchorScreenPoint) noexcept {
        cancelTouchSequence();

        const double zoomFactor = 1.0 + magnification;
        if (zoomFactor <= 0.0) {
            return false;
        }

        viewState.zoomAtScreenPoint(zoomFactor, anchorScreenPoint.x, anchorScreenPoint.y);
        return true;
    }

private:
    static constexpr double kSingleFingerTapMaxTravel = 0.02;

    bool isPointerDragging_ = false;
    bool singleFingerTapCandidate_ = false;
    geometry::Point2d singleFingerTapStart_{};
    geometry::Point2d lastThreeFingerCentroid_{};
    bool hasThreeFingerCentroid_ = false;
};

}  // namespace aaplcad::graphics