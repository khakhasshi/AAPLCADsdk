#pragma once

#include "aaplcad/geometry/point2d.h"

namespace aaplcad::graphics {

class ViewState2d {
public:
    [[nodiscard]] double zoom() const noexcept {
        return zoom_;
    }

    [[nodiscard]] double panX() const noexcept {
        return panX_;
    }

    [[nodiscard]] double panY() const noexcept {
        return panY_;
    }

    void reset() noexcept {
        zoom_ = 1.0;
        panX_ = 0.0;
        panY_ = 0.0;
    }

    void panByScreenDelta(double deltaX, double deltaY) noexcept {
        panX_ += deltaX;
        panY_ += deltaY;
    }

    void zoomAtScreenPoint(double zoomFactor, double anchorX, double anchorY) noexcept {
        if (zoomFactor <= 0.0) {
            return;
        }

        const double clampedFactor = clampZoomFactor(zoomFactor);
        const double previousZoom = zoom_;
        const double nextZoom = clampZoomValue(previousZoom * clampedFactor);
        const double appliedFactor = nextZoom / previousZoom;

        panX_ = anchorX - (anchorX - panX_) * appliedFactor;
        panY_ = anchorY - (anchorY - panY_) * appliedFactor;
        zoom_ = nextZoom;
    }

    [[nodiscard]] geometry::Point2d worldToScreen(geometry::Point2d point) const noexcept {
        return {point.x * zoom_ + panX_, point.y * zoom_ + panY_};
    }

    [[nodiscard]] geometry::Point2d screenToWorld(geometry::Point2d point) const noexcept {
        return {(point.x - panX_) / zoom_, (point.y - panY_) / zoom_};
    }

private:
    static constexpr double kMinZoom = 0.1;
    static constexpr double kMaxZoom = 20.0;
    static constexpr double kMinZoomFactor = 0.5;
    static constexpr double kMaxZoomFactor = 2.0;

    static double clampZoomValue(double value) noexcept {
        if (value < kMinZoom) {
            return kMinZoom;
        }
        if (value > kMaxZoom) {
            return kMaxZoom;
        }
        return value;
    }

    static double clampZoomFactor(double value) noexcept {
        if (value < kMinZoomFactor) {
            return kMinZoomFactor;
        }
        if (value > kMaxZoomFactor) {
            return kMaxZoomFactor;
        }
        return value;
    }

    double zoom_ = 1.0;
    double panX_ = 0.0;
    double panY_ = 0.0;
};

}  // namespace aaplcad::graphics
