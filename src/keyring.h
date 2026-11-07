#pragma once
#include <QByteArray>
#include <QStringList>
#include <functional>

class QObject;

// The system keyring that holds the saved server and scrobbling logins.
// Linux stores them with secret-tool (libsecret) and macOS in the login
// Keychain with the security command. Callers give secret-tool style
// arguments: "lookup", "store" or "clear", then attribute pairs such as
// "application" "noir" "account" <name>. macOS maps those onto security.
namespace keyring {

// True when the platform's keyring tool is present.
bool available();

// Runs one operation and calls back with whether it succeeded and what the
// tool printed. The process is killed after 15 seconds. `owner` is the QObject
// the process is parented to, so it is cleaned up with its owner.
void run(QObject *owner, const QStringList &args, const QByteArray &input,
         std::function<void(bool, QByteArray)> callback);

} // namespace keyring
