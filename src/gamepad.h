#pragma once
#include <QObject>
#include <QTimer>
#include <QVector>

struct SDL_Gamepad;

// Game controllers, read through SDL3. Each button becomes a named action for
// the interface to act on. A and B also reach the focused control as Return and
// Escape, the way a key press would. `active` holds for a minute after the last
// button press, so the interface can show controller hints only while in use.
class Gamepad : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool active READ active NOTIFY activeChanged)
  // "playstation", "xbox" or "generic": names the buttons in the guide.
  Q_PROPERTY(QString style READ style NOTIFY styleChanged)
public:
  explicit Gamepad(QObject *parent = nullptr);
  ~Gamepad() override;
  bool active() const { return m_active; }
  QString style() const { return m_style; }
  // Presses a key on the focused window, for the focused control to take.
  Q_INVOKABLE void sendKey(int key);

signals:
  void action(const QString &name);
  // The right stick's vertical deflection, -1 (up) to 1 (down), while it is pushed.
  void scroll(double amount);
  void activeChanged();
  void styleChanged();

private:
  void poll();
  void open(unsigned id);
  void markInput();

  QTimer m_poll, m_idle, m_stickRepeat, m_scroll;
  double m_rightY = 0;
  // The left stick, as a direction ("navUp", ...) or empty when centred.
  QString m_stickDir;
  double m_stickX = 0, m_stickY = 0;
  void stick(int axis, int value);
  QVector<SDL_Gamepad *> m_pads;
  bool m_active = false;
  QString m_style = "generic";
  bool m_trigger[2] = {false, false};
  bool m_sdl = false;
};
