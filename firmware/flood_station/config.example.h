#pragma once
// Copy this file to config.h and fill in your values. config.h is git-ignored so passwords stay off GitHub.

// Wi-Fi (2.4 GHz only)
#define WIFI_SSID     "YOUR_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase console > Project settings > General > Web API key
#define FIREBASE_API_KEY "AIzaSyBqKjly8EsbOADfe_Hrv2ShFjUEJc-rZl0"
// Firebase console > Realtime Database (no trailing slash)
#define DATABASE_URL     "https://flood-alert-csucc-default-rtdb.asia-southeast1.firebasedatabase.app"
// The station's own Firebase Authentication account (Email/Password)
#define DEVICE_EMAIL     "station1@floodalert.local"
#define DEVICE_PASSWORD  "YOUR_STATION_ACCOUNT_PASSWORD"
#define STATION_ID       "station1"

// Distance from the sensor face down to the 0 cm mark (riverbed / gauge zero).
#define SENSOR_HEIGHT_CM 120.0

// Defaults until thresholds are read from stations/<id>/info.
#define WARN_CM 65.0
#define CRIT_CM 85.0

#define LIVE_INTERVAL_MS    5000    // update stations/<id>/latest
#define HISTORY_INTERVAL_MS 60000   // append to stations/<id>/history and re-read thresholds

// Pins (ESP32 DevKit)
#define PIN_TRIG    5
#define PIN_ECHO    18   // HC-SR04 echo is 5 V: use a 1k/2k voltage divider into this pin
#define PIN_LED_G   25
#define PIN_LED_Y   26
#define PIN_LED_R   27
#define PIN_BUZZER  14
