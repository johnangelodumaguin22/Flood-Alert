#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "config.h"

enum Level { NORMAL, WARNING, CRITICAL };
const char* LEVEL_NAMES[] = {"normal", "warning", "critical"};

float warnCm = WARN_CM;
float critCm = CRIT_CM;
Level level = NORMAL;
unsigned long lastLive = 0;
unsigned long lastHistory = 0;
unsigned long lastBeep = 0;
bool buzzerOn = false;

WiFiClientSecure tls;
String idToken;
unsigned long tokenAt = 0;
unsigned long tokenLifeMs = 0;

float readDistanceOnce() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);
  unsigned long us = pulseIn(PIN_ECHO, HIGH, 30000);
  return us == 0 ? -1 : us * 0.0343 / 2.0;
}

// Median of 5 samples filters out the HC-SR04's occasional bad echoes.
float readDistance() {
  float s[5];
  int n = 0;
  for (int i = 0; i < 5; i++) {
    float d = readDistanceOnce();
    if (d > 2 && d < 400) s[n++] = d;
    delay(60);
  }
  if (n == 0) return -1;
  for (int i = 1; i < n; i++)
    for (int j = i; j > 0 && s[j - 1] > s[j]; j--) { float t = s[j]; s[j] = s[j - 1]; s[j - 1] = t; }
  return s[n / 2];
}

void applyOutputs() {
  digitalWrite(PIN_LED_G, level == NORMAL);
  digitalWrite(PIN_LED_Y, level == WARNING);
  digitalWrite(PIN_LED_R, level == CRITICAL);
  if (level != CRITICAL) { buzzerOn = false; digitalWrite(PIN_BUZZER, LOW); }
}

void updateBuzzer() {
  if (level != CRITICAL) return;
  if (millis() - lastBeep >= 500) {
    lastBeep = millis();
    buzzerOn = !buzzerOn;
    digitalWrite(PIN_BUZZER, buzzerOn);
  }
}

String jsonString(const String& body, const char* key) {
  int i = body.indexOf(String("\"") + key + "\"");
  if (i < 0) return "";
  i = body.indexOf('"', body.indexOf(':', i) + 1);
  int j = body.indexOf('"', i + 1);
  return (i < 0 || j < 0) ? "" : body.substring(i + 1, j);
}

float jsonNumber(const String& body, const char* key, float fallback) {
  int i = body.indexOf(String("\"") + key + "\"");
  if (i < 0) return fallback;
  i = body.indexOf(':', i);
  return i < 0 ? fallback : body.substring(i + 1).toFloat();
}

// Returns the HTTP status code; the label keeps the auth token out of the serial log.
int request(const char* method, const String& url, const String& body, String* response, const char* label) {
  HTTPClient http;
  http.setTimeout(8000);
  if (!http.begin(tls, url)) return -1;
  http.addHeader("Content-Type", "application/json");
  int code = http.sendRequest(method, body);
  if (response) *response = http.getString();
  http.end();
  Serial.printf("%s %s -> %d\n", method, label, code);
  return code;
}

void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.printf("Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 10000) {
    delay(250);
    updateBuzzer();
    Serial.print('.');
  }
  Serial.println(WiFi.status() == WL_CONNECTED ? " connected, IP " + WiFi.localIP().toString() : " failed, will retry");
}

bool ensureSignedIn() {
  // Firebase ID tokens last an hour; renew 5 minutes early.
  if (idToken.length() && millis() - tokenAt < tokenLifeMs - 300000UL) return true;
  String res;
  String body = String("{\"email\":\"") + DEVICE_EMAIL + "\",\"password\":\"" + DEVICE_PASSWORD + "\",\"returnSecureToken\":true}";
  int code = request("POST", String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") + FIREBASE_API_KEY,
                     body, &res, "sign-in");
  if (code != 200) {
    idToken = "";
    Serial.println(jsonString(res, "message"));
    return false;
  }
  idToken = jsonString(res, "idToken");
  tokenLifeMs = jsonString(res, "expiresIn").toInt() * 1000UL;
  tokenAt = millis();
  return idToken.length() > 0;
}

String dbUrl(const char* path) {
  return String(DATABASE_URL) + "/stations/" + STATION_ID + path + ".json?auth=" + idToken;
}

void publish(float levelCm, float distanceCm, bool withHistory) {
  connectWifi();
  if (WiFi.status() != WL_CONNECTED || !ensureSignedIn()) return;

  char body[160];
  snprintf(body, sizeof body,
           "{\"level_cm\":%.1f,\"distance_cm\":%.1f,\"status\":\"%s\",\"buzzer_on\":%s,\"ts\":{\".sv\":\"timestamp\"}}",
           levelCm, distanceCm, LEVEL_NAMES[level], level == CRITICAL ? "true" : "false");
  int code = request("PUT", dbUrl("/latest"), body, nullptr, "latest");
  if (code == 401) { idToken = ""; return; }

  if (withHistory) {
    snprintf(body, sizeof body, "{\"level_cm\":%.1f,\"ts\":{\".sv\":\"timestamp\"}}", levelCm);
    request("POST", dbUrl("/history"), body, nullptr, "history");

    // Thresholds can be changed in the Firebase console without reflashing.
    String info;
    if (request("GET", dbUrl("/info"), "", &info, "info") == 200) {
      warnCm = jsonNumber(info, "warn_cm", warnCm);
      critCm = jsonNumber(info, "crit_cm", critCm);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_TRIG, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_LED_G, OUTPUT);
  pinMode(PIN_LED_Y, OUTPUT);
  pinMode(PIN_LED_R, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  applyOutputs();
  // Skips TLS certificate checks to keep setup simple; pin Google's root CA with tls.setCACert() for production.
  tls.setInsecure();
  WiFi.mode(WIFI_STA);
  connectWifi();
}

void loop() {
  updateBuzzer();
  if (millis() - lastLive < LIVE_INTERVAL_MS) return;
  lastLive = millis();

  float distance = readDistance();
  if (distance < 0) {
    Serial.println("Sensor read failed");
    return;
  }
  float levelCm = constrain(SENSOR_HEIGHT_CM - distance, 0, SENSOR_HEIGHT_CM);

  // LEDs and buzzer work even when Wi-Fi or Firebase is down.
  level = levelCm >= critCm ? CRITICAL : levelCm >= warnCm ? WARNING : NORMAL;
  applyOutputs();

  bool withHistory = lastHistory == 0 || millis() - lastHistory >= HISTORY_INTERVAL_MS;
  if (withHistory) lastHistory = millis();
  publish(levelCm, distance, withHistory);
}
