# Flood Alert System

An IoT flood monitor. An ESP32 station measures river water level with an HC-SR04 ultrasonic sensor, lights green/yellow/red LEDs, sounds a buzzer at critical level, and sends readings over Wi-Fi to Firebase. The Flutter app shows the live level, alerts and the last hour's trend.

```
[HC-SR04 + LEDs + buzzer] -> ESP32 --HTTPS--> Firebase (Auth + Realtime Database) <--live-- Flutter app
```

| Path | What it is |
|---|---|
| `firmware/flood_station/` | ESP32 Arduino sketch. `config.h` holds Wi-Fi, Firebase keys, pins |
| `firebase/database.rules.json` | Realtime Database security rules |
| `firebase/seed.json` | Starter data for `stations/station1` |
| `app/` | Flutter app (Android, web, Windows) |

## Levels

| Level | Water | LEDs | Buzzer |
|---|---|---|---|
| Normal | below 65 cm | green | off |
| Warning | 65–84.9 cm | yellow | off |
| Critical | 85 cm and above | red | beeping |

Thresholds live at `stations/station1/info` (`warn_cm`, `crit_cm`). Admins can change them in the app: **What the levels mean → Edit levels**. The station reads them every minute, so no reflash is needed.

To make someone an admin, open the Realtime Database Data tab and add `admins/<their User UID>` = `true` (boolean). The UID is under Authentication → Users. They see the **Edit levels** button the next time they open the dashboard. The rules require warning ≥ 1 cm, warning < critical, and critical ≤ `max_cm`.

## Database layout (Realtime Database)

```
stations/station1/
  info        {name, warn_cm, crit_cm, max_cm,             warn_cm/crit_cm editable by admins in the app,
               updated_by, updated_at}                       the rest in the console only
  device_uid  "<uid of the station's Auth account>"         edited in the console only
  latest      {level_cm, distance_cm, status, buzzer_on, ts} written by the ESP32 every 5 s
  history/<id> {level_cm, ts}                                appended by the ESP32 every 60 s
users/<uid>   {full_name, username, email, phone, created_at}
usernames/<lowercase username> "<email>"                     lets people sign in with a username
admins/<uid>  true                                           edited in the console only
```

Rules: signed-in users can read stations. Only the station's own account can write readings. Only admins can change `warn_cm` and `crit_cm`. Nobody can edit the rest of `info`, `device_uid` or `admins` from a client. Each user can read and write only their own profile. Usernames are first come, first served.

## 1. Firebase setup

1. In the [Firebase console](https://console.firebase.google.com), create a project, for example `flood-alert-system`.
2. **Authentication → Sign-in method →** enable **Email/Password**.
3. **Authentication → Users → Add user** for the station, for example `station1@floodalert.local` with a long random password. Copy its **User UID**.
4. **Realtime Database → Create database**. Pick the nearest location (Singapore, `asia-southeast1`) and start in **locked mode**.
5. In the Data tab, add a child `stations` → `station1`, then **⋮ → Import JSON** on `station1` with `firebase/seed.json`. Replace `device_uid` with the UID from step 3.
6. Deploy the rules from this folder:
   ```
   firebase use --add          # choose your project
   firebase deploy --only database
   ```

## 2. App

```
cd app
flutterfire configure        # pick the project; writes lib/firebase_options.dart and google-services.json
flutter pub get
flutter run -d chrome        # or an Android device/emulator, or -d windows
flutter build apk
```

The dashboard updates live as soon as the station writes, with no refreshing needed.

## 3. Wiring (ESP32 DevKit)

| Part | Part pin | ESP32 pin |
|---|---|---|
| HC-SR04 | VCC | 5V (VIN) |
| HC-SR04 | GND | GND |
| HC-SR04 | TRIG | GPIO 5 |
| HC-SR04 | ECHO | GPIO 18 **through a voltage divider** (ECHO → 1 kΩ → GPIO 18 → 2 kΩ → GND) |
| Green LED | + (via 220 Ω) | GPIO 25 |
| Yellow LED | + (via 220 Ω) | GPIO 26 |
| Red LED | + (via 220 Ω) | GPIO 27 |
| Active buzzer | + | GPIO 14 (use an NPN transistor if it draws more than ~20 mA) |

Mount the sensor facing straight down over the water. Measure from the sensor face to the gauge's 0 cm mark and put that number in `SENSOR_HEIGHT_CM`. Water level = `SENSOR_HEIGHT_CM` − measured distance.

## 4. Firmware

1. Arduino IDE → Boards Manager → install **esp32 by Espressif**. Select **ESP32 Dev Module**. No extra libraries are needed.
2. Copy `firmware/flood_station/config.example.h` to `config.h` in the same folder (`config.h` is git-ignored), then edit it:
   - Wi-Fi name and password
   - `FIREBASE_API_KEY`: Project settings → General → Web API key
   - `DATABASE_URL`: shown at the top of the Realtime Database page
   - `DEVICE_EMAIL` / `DEVICE_PASSWORD`: the station account from step 1.3
   - `SENSOR_HEIGHT_CM`
3. Upload, then open Serial Monitor at 115200 baud. Expect `POST sign-in -> 200`, then `PUT latest -> 200` every 5 seconds.

The LEDs and buzzer run locally, so they keep warning people even if Wi-Fi or Firebase is down. The app marks the station offline after 60 seconds without a reading.

## Before real deployment

- The firmware skips TLS certificate checks (`tls.setInsecure()`). Pin Google's root CA with `tls.setCACert()`.
- `usernames/` is publicly readable, so anyone who knows a username can learn its email. Keep it if username sign-in matters, or remove username sign-in.
- Push notifications/SMS for alerts are not built yet. The phone field is stored for that. Firebase Cloud Messaging is the natural next step.
- History grows by about 1,440 entries per day. Add a cleanup, for example a scheduled Cloud Function, if you keep the station running for months.
