#pragma once

#include <cstdint>
#include <string>

namespace aaplcad::platform {

enum class InputDevice {
    unknown,
    mouse,
    trackpad,
    keyboard,
};

enum class InputAction {
    move,
    buttonDown,
    buttonUp,
    scroll,
    magnify,
    rotate,
    keyDown,
    keyUp,
};

enum ModifierFlags : std::uint32_t {
    modifierNone = 0,
    modifierShift = 1u << 0,
    modifierControl = 1u << 1,
    modifierOption = 1u << 2,
    modifierCommand = 1u << 3,
};

struct PointerEvent {
    InputDevice device = InputDevice::unknown;
    InputAction action = InputAction::move;
    double x = 0.0;
    double y = 0.0;
    double deltaX = 0.0;
    double deltaY = 0.0;
    std::uint32_t modifiers = modifierNone;
};

[[nodiscard]] std::string toString(InputDevice device);
[[nodiscard]] std::string toString(InputAction action);
[[nodiscard]] std::string describe(const PointerEvent& event);

}  // namespace aaplcad::platform
