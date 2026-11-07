// macOS media keys and Now Playing. MediaPlayer's remote command center gets
// the keyboard and headset buttons, and MPNowPlayingInfoCenter shows the track
// in Control Centre and on the lock screen. Both want the app to be a bundle,
// which CMake builds on macOS.
#include "nowplaying.h"
#include "artworkurl.h"
#include "backend.h"
#include <QtCore/qcore_mac_objc.h>
#include <QUrl>
#include <QVariantMap>
#import <AppKit/AppKit.h>
#import <MediaPlayer/MediaPlayer.h>

namespace {

Backend *player = nullptr;

// Backend positions and durations are in milliseconds; MediaPlayer wants seconds.
void publish() {
  MPNowPlayingInfoCenter *center = MPNowPlayingInfoCenter.defaultCenter;
  const QVariantMap track = player->current();
  if (track.isEmpty()) {
    center.nowPlayingInfo = nil;
    return;
  }
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  info[MPMediaItemPropertyTitle] = track.value("title").toString().toNSString();
  info[MPMediaItemPropertyArtist] = track.value("artist").toString().toNSString();
  info[MPMediaItemPropertyAlbumTitle] = track.value("album").toString().toNSString();
  info[MPMediaItemPropertyPlaybackDuration] = @(player->duration() / 1000.0);
  info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(player->position() / 1000.0);
  info[MPNowPlayingInfoPropertyPlaybackRate] = @(player->playing() ? 1.0 : 0.0);
  // Only a local cover can be handed over as an image here. Covers that are
  // still remote are not shown in Now Playing yet.
  const QUrl art = artworkurl::forDesktop(QUrl(player->displayArt(track)));
  if (art.isLocalFile()) {
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:art.toLocalFile().toNSString()];
    if (image)
      info[MPMediaItemPropertyArtwork] = [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size
                                                                         requestHandler:^NSImage *(CGSize) {
                                                                           return image;
                                                                         }];
  }
  center.nowPlayingInfo = info;
}

void wireCommands() {
  MPRemoteCommandCenter *commands = MPRemoteCommandCenter.sharedCommandCenter;
  [commands.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *) {
    player->play();
    return MPRemoteCommandHandlerStatusSuccess;
  }];
  [commands.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *) {
    player->pause();
    return MPRemoteCommandHandlerStatusSuccess;
  }];
  [commands.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *) {
    player->toggle();
    return MPRemoteCommandHandlerStatusSuccess;
  }];
  [commands.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *) {
    player->next();
    return MPRemoteCommandHandlerStatusSuccess;
  }];
  [commands.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *) {
    player->previous();
    return MPRemoteCommandHandlerStatusSuccess;
  }];
  [commands.changePlaybackPositionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
    auto *seek = static_cast<MPChangePlaybackPositionCommandEvent *>(event);
    player->seek(static_cast<qint64>(seek.positionTime * 1000.0));
    return MPRemoteCommandHandlerStatusSuccess;
  }];
}

} // namespace

void registerNowPlaying(Backend *backend) {
  player = backend;
  wireCommands();
  QObject::connect(backend, &Backend::trackChanged, backend, [] { publish(); });
  QObject::connect(backend, &Backend::playbackChanged, backend, [] { publish(); });
  QObject::connect(backend, &Backend::seeked, backend, [](qint64) { publish(); });
  publish();
}
