#include "keyring.h"
#include <QMap>
#include <QObject>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>
#include <memory>

namespace keyring {
namespace {

#ifdef Q_OS_MACOS
// The attribute pairs of a secret-tool call, in order. An option such as
// "--label=..." takes no value here and is skipped.
QMap<QString, QString> attributes(const QStringList &args) {
  QMap<QString, QString> out;
  for (qsizetype i = 1; i < args.size();) {
    if (args[i].startsWith("--")) {
      ++i;
      continue;
    }
    if (i + 1 < args.size())
      out.insert(args[i], args[i + 1]);
    i += 2;
  }
  return out;
}

// security -i reads its commands from stdin, so the password is never in the
// argument list where other users could see it. Inside its double quotes a
// backslash and a double quote are escaped with a backslash.
QString quoted(const QString &value) {
  QString out = value;
  out.replace('\\', "\\\\");
  out.replace('"', "\\\"");
  return "\"" + out + "\"";
}

struct Command {
  QString program;
  QStringList args;
  QByteArray input;
};

// The security command for one secret-tool call. A store writes the secret into
// the command line that security -i reads from its input.
Command toSecurity(const QStringList &args, const QByteArray &input) {
  const QString op = args.value(0);
  const auto attrs = attributes(args);
  const QString service = attrs.value("application", "noir");
  const QString account = attrs.value("account");
  if (op == "lookup")
    return {"security", {"find-generic-password", "-s", service, "-a", account, "-w"}, {}};
  if (op == "clear")
    return {"security", {"delete-generic-password", "-s", service, "-a", account}, {}};
  const QString line = "add-generic-password -U -s " + quoted(service) + " -a " +
                       quoted(account) + " -w " + quoted(QString::fromUtf8(input)) + "\n";
  return {"security", {"-i"}, line.toUtf8()};
}
#endif

} // namespace

bool available() {
#ifdef Q_OS_MACOS
  return !QStandardPaths::findExecutable("security").isEmpty();
#else
  return !QStandardPaths::findExecutable("secret-tool").isEmpty();
#endif
}

void run(QObject *owner, const QStringList &args, const QByteArray &input,
         std::function<void(bool, QByteArray)> callback) {
  if (!available()) {
    callback(false, {});
    return;
  }
  QString program = "secret-tool";
  QStringList programArgs = args;
  QByteArray data = input;
#ifdef Q_OS_MACOS
  const Command command = toSecurity(args, input);
  program = command.program;
  programArgs = command.args;
  data = command.input;
#endif
  auto *process = new QProcess(owner);
  auto *timer = new QTimer(process);
  timer->setSingleShot(true);
  auto done = std::make_shared<bool>(false);
  auto finish = [process, done, callback](bool ok) {
    if (*done)
      return;
    *done = true;
    callback(ok, process->readAllStandardOutput());
    process->deleteLater();
  };
  QObject::connect(process, &QProcess::errorOccurred, owner, [finish](QProcess::ProcessError e) {
    if (e == QProcess::FailedToStart)
      finish(false);
  });
  QObject::connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), owner,
                   [finish](int code, QProcess::ExitStatus status) {
                     finish(code == 0 && status == QProcess::NormalExit);
                   });
  QObject::connect(timer, &QTimer::timeout, process, [process] { process->kill(); });
  process->start(program, programArgs);
  process->write(data);
  process->closeWriteChannel();
  timer->start(15000);
}

} // namespace keyring
