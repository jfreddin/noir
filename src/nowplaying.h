#pragma once

class Backend;

// Connects the macOS media keys and the Now Playing widget to the player. On
// Linux the same job is MPRIS, in mpris.h. Both read the backend's signals and
// send its playback calls, so the player behaves the same on either system.
void registerNowPlaying(Backend *backend);
