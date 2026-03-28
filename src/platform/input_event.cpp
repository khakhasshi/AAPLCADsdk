#include "aaplcad/platform/input_event.h"

#include <sstream>

namespace aaplcad::platform {

std::string toString(InputDevice device) {
    switch (device) {
    case InputDevice::unknown:
        return "unknown";
    case InputDevice::mouse:
        return "mouse";
    case InputDevice::trackpad:
        return "trackpad";
    case InputDevice::keyboard:
        return "keyboard";
    }

    return "unknown";
}

std::string toString(InputAction action) {
    switch (action) {
    case InputAction::move:
        return "move";
    case InputAction::buttonDown:
        return "buttonDown";
    case InputAction::buttonUp:
        return "buttonUp";
    case InputAction::scroll:
        return "scroll";
    case InputAction::magnify:
        return "magnify";
    case InputAction::rotate:
        return "rotate";
    case InputAction::keyDown:
        return "keyDown";
    case InputAction::keyUp:
        return "keyUp";
    }

    return "unknown";
}

std::string describe(const PointerEvent& event) {
    std::ostringstream stream;
    stream << toString(event.device) << ':' << toString(event.action)
           << " @(" << event.x << ", " << event.y << ")"
           << " d(" << event.deltaX << ", " << event.deltaY << ")"
           << " mods=" << event.modifiers;
    return stream.str();
}

}  // namespace aaplcad::platform
