# Telemetry Server API

The telemetry server API will receive anonymized data to provide usage statistics:
- device_id: Generated at random upon initial app opening. Used only to anonymously count an install as unique.
- event: `app_exit`, `app_open`, `login_success`, `panel_open`, `panel_close`, or `stream_play`.
- app_version: Version of the app installed.
- roku_model: Roku model number string.
- firmware: Roku firmware version string.
- display_mode: Display information.
- event_data: Extra data, such as the name of the camera selected.
- client_timestamp: Event timestamp.

Event API requires a token, but this token should be treated as public because it can easily be
extracted from the packaged app.

Fetching statistics from the `/stats` endpoint returns the following data:
```json
{
  "events_by_type": {
    "app_open": 3,
    "login_success": 2,
    "panel_close": 5,
    "panel_open": 5,
    "stream_play": 4
  },
  "popular_cameras": {
    "dirc-5": 3,
    "dmrm2-5": 1
  },
  "roku_models": {
    "100012585": 2,
    "55S20": 1
  },
  "total_events": 19,
  "unique_devices_24h": 3,
  "unique_devices_7d": 3,
  "unique_devices_all_time": 3
}
```

It is recommended to perform additional filtering on requests to cut down on bot noise.

## Setup

Copy `env.example` to `.env` and generate random tokens:
```shell
python3 -c "import secrets; print(secrets.token_urlsafe(32))
```

Run the Docker Compose stack:
```shell
# If you run into permission issues, make sure the data directory is owned by 1001:1001
sudo chown 1001:1001 ./data
docker compose up -d
```
