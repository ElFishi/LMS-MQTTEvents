
# MQTTEvents (LMS / Lyrion plugin)

Publishes **power** and **mixer** (volume/muting) events from Lyrion Music Server (formerly Logitech Media Server) to **MQTT**.
Includes a Settings page to configure broker **host/port**, optional **username/password** (no TLS), **base topic**, and **retain** flag. 
Also provides **Test connection** and **Publish example payloads** buttons.

## Installation (manual)
1. This plugin comes with its own copy of the Perl module [Net::MQTT::Simple](https://metacpan.org/pod/Net::MQTT::Simple). If this doesn't work you can install it on the LMS host (e.g., `cpan Net::MQTT::Simple` or your distro package `libnet-mqtt-simple-perl`).
2. Copy the `MQTTEvents` folder into your LMS third-party **Plugins** directory.
   - The correct path for manual plugins is listed at the bottom of **Settings → Information** in LMS.
   - Normally it is not the path with "cache"
3. Restart LMS.
4. Open **Settings → Plugins → MQTT Events (Broker Settings)** and configure your broker.

## Topics & payloads
- Power:  `<base>/<player-mac>/power`        → `{"player":"<player-mac>", "key":"power", "value": 0|1 }`
- Volume: `<base>/<player-mac>/mixer/volume` → `{"player":"<player-mac>", "key":"volume", "value": 0..100 }`
- Muting: `<base>/<player-mac>/mixer/muting` → `{"player":"<player-mac>", "key":"muting", "value": 0|1 }`

Default base is `lms`.

## Notes
- Auth is optional. TLS is **not** used.
- Publishing uses QoS 0 (`Net::MQTT::Simple`).
- Logging can be set to ERROR/WARN/INFO/DEBUG in Advanced/Logging.

## Disclaimer
- This plugin was almost entirely written by LLMs. 
- It is just a proof-of-concept and not fully tested. Use it at your own risk.
- This repository is not maintained.
