
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

## Home Assistant Integration

The Home Assistant MQTT integration can expose the values published by this plugin as sensors. Once [Home Assistant is connected to your MQTT broker](https://www.home-assistant.io/integrations/mqtt), you can use its [MQTT discovery feature](https://www.home-assistant.io/integrations/mqtt#mqtt-discovery) to register the sensors automatically. To do so, publish a retained message similar to the one below to the `homeassistant/device/<player-mac>/config` topic.

```json
{   
  "dev": {
    "ids": "<player-mac>",
    "name": "<player-name> LMS Control"
  },
  "o": {
    "name": "lms2mqtt"
  },
  "cmps": {
    "power": {
      "p": "binary_sensor",   
      "name": "power",
      "state_topic": "lms/<player-mac>/power",
      "value_template": "{{ 'ON' if value_json.value == 1 else 'OFF' }}",
      "device_class": "power",
      "unique_id": "<player-mac>_power"
    },
    "volume": {
      "p": "sensor",
      "name": "volume",
      "state_topic": "lms/<player-mac>/mixer/volume",
      "value_template": "{{ float(value_json.value) / 100 }}",
      "unique_id": "<player-mac>_volume"
    },
    "muting": {
      "p": "binary_sensor",
      "name": "is_volume_muted",
      "state_topic": "lms/<player-mac>/mixer/muting",
      "value_template": "{{ 'ON' if value_json.value == 1 else 'OFF' }}",
      "unique_id": "<player-mac>_muted"
    }
  }
}
```

[Mosquitto](https://mosquitto.org) users can save the payload to a file and publish it with:

```sh
mosquitto_pub -u <user> -P <password> -h <mqtt-host> -t "homeassistant/device/<player-mac>/config" --retain -f <payload-file>
```

Once the sensors are registered, you can use them to drive automations on other devices. This is particularly useful when streaming to a fixed-volume DAC connected to an external amplifier, allowing Lyrion to control the amplifier's volume and power state.
