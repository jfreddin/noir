#include "playbacknotifier.h"
#ifdef Q_OS_LINUX
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>

static QDBusMessage message(const QString &method) {
  return QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", method);
}
PlaybackNotifier::PlaybackNotifier(QObject *parent) : QObject(parent) {
  auto bus=QDBusConnection::sessionBus();
  bus.connect("org.freedesktop.Notifications","/org/freedesktop/Notifications","org.freedesktop.Notifications","NotificationClosed",this,SLOT(notificationClosed(uint,uint)));
  auto watcher=new QDBusServiceWatcher("org.freedesktop.Notifications",bus,QDBusServiceWatcher::WatchForOwnerChange,this);
  connect(watcher,&QDBusServiceWatcher::serviceOwnerChanged,this,[this](const QString &,const QString &oldOwner,const QString &){m_id=0;if(!oldOwner.isEmpty())++m_generation;});
}
void PlaybackNotifier::show(const QString &title,const QString &artist) {
  if(title.isEmpty())return;
  m_queued={{"title",title.left(200)},{"artist",artist.left(200)}};
  flush();
}
void PlaybackNotifier::close(uint id) {
  if(!id)return;
  auto request=message("CloseNotification");request<<id;
  QDBusConnection::sessionBus().asyncCall(request,2000);
}
void PlaybackNotifier::clear() {
  m_queued.clear();++m_generation;close(m_id);m_id=0;
}
void PlaybackNotifier::notificationClosed(uint id,uint) {if(id==m_id)m_id=0;}
void PlaybackNotifier::flush() {
  if(m_pending||m_queued.isEmpty())return;
  const auto track=m_queued;m_queued.clear();m_pending=true;
  const auto generation=m_generation;
  auto request=message("Notify");
  const QVariantMap hints{{"desktop-entry","noir"},{"category","music"},{"transient",true},{"suppress-sound",true},{"urgency",QVariant::fromValue(uchar(0))}};
  request<<QString("Noir")<<m_id<<QString("noir")<<track.value("title").toString()<<track.value("artist").toString().toHtmlEscaped()<<QStringList{}<<hints<<5000;
  auto pending=new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(request,2000),this);
  connect(pending,&QDBusPendingCallWatcher::finished,this,[this,generation](QDBusPendingCallWatcher *call){
    QDBusPendingReply<uint> result=*call;
    if(!result.isError()){if(generation==m_generation)m_id=result.value();else close(result.value());}
    m_pending=false;call->deleteLater();flush();
  });
}
#elif defined(Q_OS_MACOS)
// Notification Center, through osascript. It needs no app bundle or entitlement,
// and the notification cannot be recalled, so clear() and the closed signal do nothing.
#include <QProcess>
PlaybackNotifier::PlaybackNotifier(QObject *parent) : QObject(parent) {}
void PlaybackNotifier::show(const QString &title, const QString &artist) {
  if (title.isEmpty())
    return;
  auto quote = [](QString text) {
    return text.left(200).replace('\\', "\\\\").replace('"', "\\\"");
  };
  // The track title leads and the artist goes below it, as on Linux.
  const QString script = QStringLiteral("display notification \"%1\" with title \"%2\"")
                             .arg(quote(artist), quote(title));
  QProcess::startDetached("osascript", {"-e", script});
}
void PlaybackNotifier::clear() {}
void PlaybackNotifier::notificationClosed(uint, uint) {}
#endif
