#include <cmath>
#include "gamepad.h"
#include <SDL3/SDL.h>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QWindow>

namespace {
// The hint stays up for a minute after the last press.
constexpr int kIdleMs = 60000;
// Polling runs at 20ms: quick enough for button presses, and the cost is a few
// microseconds per poll, with no work done while nothing is pressed.
constexpr int kPollMs = 20;
}

Gamepad::Gamepad(QObject *parent) : QObject(parent) {
  m_sdl = SDL_InitSubSystem(SDL_INIT_GAMEPAD);
  if (!m_sdl) return;
  int count = 0;
  if (SDL_JoystickID *ids = SDL_GetGamepads(&count)) {
    for (int i = 0; i < count; ++i) open(ids[i]);
    SDL_free(ids);
  }
  m_poll.setInterval(kPollMs);
  connect(&m_poll, &QTimer::timeout, this, &Gamepad::poll);
  m_idle.setSingleShot(true);
  m_idle.setInterval(kIdleMs);
  connect(&m_idle, &QTimer::timeout, this, [this] {
    if (m_active) { m_active = false; emit activeChanged(); }
  });
  m_poll.start();
  // Holding the stick repeats its direction: once, a pause, then steadily.
  m_stickRepeat.setSingleShot(true);
  m_stickRepeat.setInterval(350);
  connect(&m_stickRepeat, &QTimer::timeout, this, [this] {
    if (m_stickDir.isEmpty()) return;
    emit action(m_stickDir);
    m_stickRepeat.setSingleShot(false);
    m_stickRepeat.setInterval(120);
    m_stickRepeat.start();
  });
  // The right stick scrolls: it emits a steady amount while it is pushed, so the
  // speed follows the deflection and not the rate the device sends events.
  m_scroll.setInterval(16);
  connect(&m_scroll, &QTimer::timeout, this, [this] { emit scroll(m_rightY); });
}

Gamepad::~Gamepad() {
  for (SDL_Gamepad *pad : m_pads) SDL_CloseGamepad(pad);
  if (m_sdl) SDL_QuitSubSystem(SDL_INIT_GAMEPAD);
}

void Gamepad::open(unsigned id) {
  SDL_Gamepad *pad = SDL_OpenGamepad(id);
  if (!pad) return;
  m_pads.append(pad);
  // The first controller names the buttons; the guide follows its layout.
  if (m_pads.size() == 1) {
    const SDL_GamepadType type = SDL_GetGamepadType(pad);
    const QString next = (type == SDL_GAMEPAD_TYPE_PS3 || type == SDL_GAMEPAD_TYPE_PS4 || type == SDL_GAMEPAD_TYPE_PS5) ? "playstation"
                       : (type == SDL_GAMEPAD_TYPE_XBOX360 || type == SDL_GAMEPAD_TYPE_XBOXONE) ? "xbox" : "generic";
    if (next != m_style) { m_style = next; emit styleChanged(); }
  }
}

void Gamepad::poll() {
  SDL_Event event;
  while (SDL_PollEvent(&event)) {
    if (event.type == SDL_EVENT_GAMEPAD_ADDED) {
      open(event.gdevice.which);
      continue;
    }
    // The analog triggers are read as presses once they pass half way.
    if (event.type == SDL_EVENT_GAMEPAD_AXIS_MOTION &&
        (event.gaxis.axis == SDL_GAMEPAD_AXIS_LEFT_TRIGGER || event.gaxis.axis == SDL_GAMEPAD_AXIS_RIGHT_TRIGGER)) {
      const int index = event.gaxis.axis == SDL_GAMEPAD_AXIS_LEFT_TRIGGER ? 0 : 1;
      const bool pressed = event.gaxis.value > 16384;
      if (pressed != m_trigger[index]) {
        m_trigger[index] = pressed;
        if (pressed) {
          markInput();
          emit action(index == 0 ? "triggerLeft" : "triggerRight");
        }
      }
      continue;
    }
    if (event.type == SDL_EVENT_GAMEPAD_AXIS_MOTION &&
        (event.gaxis.axis == SDL_GAMEPAD_AXIS_LEFTX || event.gaxis.axis == SDL_GAMEPAD_AXIS_LEFTY)) {
      stick(event.gaxis.axis, event.gaxis.value);
      continue;
    }
    if (event.type == SDL_EVENT_GAMEPAD_AXIS_MOTION && event.gaxis.axis == SDL_GAMEPAD_AXIS_RIGHTY) {
      // A dead zone of a fifth of the throw, then the rest scaled to 0..1.
      const double v = event.gaxis.value / 32768.0;
      const double band = 0.2;
      m_rightY = std::abs(v) < band ? 0 : (v - (v > 0 ? band : -band)) / (1 - band);
      if (m_rightY != 0) {
        markInput();
        if (!m_scroll.isActive()) m_scroll.start();
      } else {
        m_scroll.stop();
      }
      continue;
    }
    if (event.type != SDL_EVENT_GAMEPAD_BUTTON_DOWN) continue;
    markInput();
    switch (event.gbutton.button) {
      case SDL_GAMEPAD_BUTTON_SOUTH:       emit action("select"); break;    // A, press the focused control
      case SDL_GAMEPAD_BUTTON_EAST:        emit action("back"); break;      // B, back
      case SDL_GAMEPAD_BUTTON_WEST:        emit action("playPause"); break; // X, play/pause
      case SDL_GAMEPAD_BUTTON_NORTH:       emit action("nowPlaying"); break; // Y, Now playing
      case SDL_GAMEPAD_BUTTON_DPAD_LEFT:   emit action("previous"); break;
      case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:  emit action("next"); break;
      case SDL_GAMEPAD_BUTTON_DPAD_UP:     emit action("volumeUp"); break;
      case SDL_GAMEPAD_BUTTON_DPAD_DOWN:   emit action("volumeDown"); break;
      case SDL_GAMEPAD_BUTTON_LEFT_STICK:  emit action("loop"); break;
      case SDL_GAMEPAD_BUTTON_RIGHT_STICK: emit action("shuffle"); break;
      case SDL_GAMEPAD_BUTTON_START:
      case SDL_GAMEPAD_BUTTON_GUIDE:       emit action("settings"); break;
      case SDL_GAMEPAD_BUTTON_BACK:           emit action("pins"); break;      // Select, Share on a PS4
      case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:  emit action("tabPrevious"); break;
      case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: emit action("tabNext"); break;
      default: break;
    }
  }
}

// The stick moves the focus. A direction is read once it passes half way.
void Gamepad::stick(int axis, int value) {
  const double v = value / 32768.0;
  if (axis == SDL_GAMEPAD_AXIS_LEFTX) m_stickX = v;
  else if (axis == SDL_GAMEPAD_AXIS_LEFTY) m_stickY = v;
  else return;
  // Only the stick's dominant axis counts, so a push up with a little sideways
  // drift still moves up instead of flipping between up and sideways.
  QString dir;
  if (std::abs(m_stickX) >= std::abs(m_stickY)) {
    if (m_stickX > 0.5) dir = "navRight";
    else if (m_stickX < -0.5) dir = "navLeft";
  } else {
    if (m_stickY < -0.5) dir = "navUp";
    else if (m_stickY > 0.5) dir = "navDown";
  }
  if (dir == m_stickDir) return;
  m_stickDir = dir;
  m_stickRepeat.stop();
  if (dir.isEmpty()) return;
  markInput();
  emit action(dir);
  m_stickRepeat.setSingleShot(true);
  m_stickRepeat.setInterval(350);
  m_stickRepeat.start();
}

void Gamepad::markInput() {
  if (!m_active) { m_active = true; emit activeChanged(); }
  m_idle.start();
}

void Gamepad::sendKey(int key) {
  QWindow *window = QGuiApplication::focusWindow();
  if (!window) return;
  QCoreApplication::postEvent(window, new QKeyEvent(QEvent::KeyPress, key, Qt::NoModifier));
  QCoreApplication::postEvent(window, new QKeyEvent(QEvent::KeyRelease, key, Qt::NoModifier));
}
