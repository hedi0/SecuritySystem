#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "esp_camera.h"
#include <UniversalTelegramBot.h>
#include <time.h>
#include <ESP32Servo.h>
#include <EEPROM.h>

//WIFI & TELEGRAM CONFIGURATION
const char* ssid = "WIFI-NAME";
const char* password = "WIFI-PASSWORD";
String BOTtoken = "000000:xxxx-XXXXX";
String CHAT_ID = "id-here";

//FACE RECOGNITION SERVER
const char* SERVER_URL = "http://YOUR-LAPTOP-IP:5000/recognize";

// FIREBASE CONFIGURATION   (example : default-rtdb.firebaseio.com)
const char* FIREBASE_HOST = "PASTE-YOUR-URL-HERE";

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Hardware pins
#define FLASH_LED_PIN 4
#define TRIG_PIN 12
#define ECHO_PIN 13
#define PAN_SERVO_PIN 14
#define DOOR_SERVO_PIN 15
#define BUZZER_PIN 2
#define VIBRATION_PIN 33

// CONSTANTS
#define MAX_DISTANCE 5
#define NUM_PAN_POSITIONS 4
#define DOOR_OPEN_ANGLE 90
#define DOOR_CLOSE_ANGLE 0

// Vibration detection constants
#define VIBRATION_DEBOUNCE_TIME 2000  // 2 seconds between vibration alerts
#define VIBRATION_THRESHOLD 3         // Number of consecutive detections needed
#define VIBRATION_CHECK_INTERVAL 100  // Check every 100ms

// Firebase update interval
const unsigned long FIREBASE_UPDATE_INTERVAL = 5000; // 5 seconds
unsigned long lastFirebaseUpdate = 0;

// EEPROM addresses
#define EEPROM_SIZE 10
#define EEPROM_REBOOT_FLAG_ADDR 0
#define EEPROM_MESSAGE_ID_ADDR 1

// GLOBAL VARIABLES
WiFiClientSecure clientTCP;
UniversalTelegramBot bot(BOTtoken, clientTCP);
Servo panServo;
Servo doorServo;

int panPositions[NUM_PAN_POSITIONS] = {30, 60, 120, 150};
int currentPanIndex = 0;
unsigned long lastTimeBotRan = 0;
const int botRequestDelay = 1000;

bool systemActive = false;
bool faceSearchMode = false;
bool sendPhoto = false;
bool boolDistanceState = false;
int captureAttempts = 0;

// Vibration detection variables
unsigned long lastVibrationAlert = 0;
bool vibrationAlertCooldown = false;
int vibrationDetectionCount = 0;
unsigned long lastVibrationCheck = 0;
bool lastVibrationState = HIGH;

// Connection notification flag
bool connectionNotified = false;

// Reboot flag
bool rebootFlag = false;
unsigned long rebootTime = 0;
const unsigned long rebootDelay = 5000; // Wait 5 seconds before processing commands after reboot

// Store last processed message ID to avoid processing old commands
int lastProcessedMessageId = -1;

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 0;
const int daylightOffset_sec = 0;

// Base64 encoding table
const char PROGMEM b64_alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                     "abcdefghijklmnopqrstuvwxyz"
                                     "0123456789+/";

// BASE64 ENCODING FUNCTION 
String base64_encode(const uint8_t* data, size_t length) {
    String encoded = "";
    size_t i = 0;
    uint8_t char_array_3[3];
    uint8_t char_array_4[4];

    while (length--) {
        char_array_3[i++] = *(data++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for(i = 0; i < 4; i++) {
                encoded += (char)pgm_read_byte(&b64_alphabet[char_array_4[i]]);
            }
            i = 0;
        }
    }

    if (i) {
        for(size_t j = i; j < 3; j++) {
            char_array_3[j] = '\0';
        }

        char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);

        for (size_t j = 0; j < i + 1; j++) {
            encoded += (char)pgm_read_byte(&b64_alphabet[char_array_4[j]]);
        }

        while(i++ < 3) {
            encoded += '=';
        }
    }

    return encoded;
}

// FUNCTION PROTOTYPES
void configInitCamera();
float getDistance();
void LEDFlash_State(bool state);
bool isNightTime();
String sendPhotoTelegram(String caption = "");
String sendToFaceRecognitionServer(camera_fb_t *fb);
void processSecurityCycle();
void triggerAlert(bool isIntruder);
void handleNewMessages(int numNewMessages);
void openDoor();
void closeDoor();
void checkVibrationSensor();
void sendVibrationAlert();
void sendConnectionNotification();
void safeReboot();  // Safe reboot function

// Firebase Functions
void sendToFirebase(String eventType, String faceName = "None", bool faceDetected = false);
void sendSystemStatusToFirebase();
String createFirebaseJson(String eventType, String faceName = "None", bool faceDetected = false);

void setup() {
    WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
    
    // Initialize EEPROM
    EEPROM.begin(EEPROM_SIZE);
    
    // Check if we just rebooted
    bool wasRebooted = EEPROM.read(EEPROM_REBOOT_FLAG_ADDR) == 1;
    
    // Clear reboot flag
    EEPROM.write(EEPROM_REBOOT_FLAG_ADDR, 0);
    EEPROM.commit();
    
    Serial.begin(115200);
    delay(100);  // Give serial time to initialize
    
    Serial.println("\n\nSecurity System");
    Serial.println("-----------------------------------");
    
    if (wasRebooted) {
        Serial.println("System rebooted successfully");
        rebootFlag = true;
        rebootTime = millis();
    }
    
    // Initialize pins
    pinMode(FLASH_LED_PIN, OUTPUT);
    LEDFlash_State(LOW);
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);
    pinMode(BUZZER_PIN, OUTPUT);
    pinMode(VIBRATION_PIN, INPUT_PULLUP);
    
    // Initialize servos
    panServo.attach(PAN_SERVO_PIN);
    doorServo.attach(DOOR_SERVO_PIN);
    panServo.write(panPositions[0]);
    closeDoor();
    
    // Initialize camera
    Serial.println("Initializing camera...");
    configInitCamera();
    
    // Connect to WiFi
    Serial.print("Connecting to WiFi: ");
    Serial.println(ssid);
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    clientTCP.setCACert(TELEGRAM_CERTIFICATE_ROOT);
    
    int timeout = 0;
    while (WiFi.status() != WL_CONNECTED && timeout < 30) {
        delay(500);
        Serial.print(".");
        timeout++;
        LEDFlash_State(!digitalRead(FLASH_LED_PIN));
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi connected!");
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
        
        // Configure time
        configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
        
        // Test beep
        digitalWrite(BUZZER_PIN, HIGH);
        delay(100);
        digitalWrite(BUZZER_PIN, LOW);
        
        // Send connection notification to Telegram
        sendConnectionNotification();
        
        // Send initial status to Firebase
        sendToFirebase("status");
        sendSystemStatusToFirebase();
        
        // Get the latest message ID to avoid processing old commands
        if (rebootFlag) {
            Serial.println("Getting latest messages to clear old commands...");
            int numNewMessages = bot.getUpdates(0);  // Get all messages
            if (numNewMessages > 0) {
                // Store the latest message ID
                lastProcessedMessageId = bot.messages[numNewMessages - 1].message_id;
                Serial.println("Cleared old messages from queue");
            }
        }
        
    } else {
        Serial.println("\nWiFi connection failed!");
        for (int i = 0; i < 5; i++) {
            digitalWrite(BUZZER_PIN, HIGH);
            delay(200);
            digitalWrite(BUZZER_PIN, LOW);
            delay(200);
        }
    }
    
    LEDFlash_State(LOW);
    Serial.println("System ready. Monitoring distance and vibration...");
    Serial.println("Firebase Integration: ACTIVE");
}

// SEND CONNECTION NOTIFICATION
void sendConnectionNotification() {
    // Get current time if available
    struct tm timeinfo;
    String timeString = "Not available";
    if (getLocalTime(&timeinfo)) {
        char buffer[20];
        strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", &timeinfo);
        timeString = String(buffer);
    }
    
    // Get MAC address
    String macAddress = WiFi.macAddress();
    
    // Create connection message
    String connectMsg = "🔌 ESP32-CAM CONNECTED!\n";
    connectMsg += "=========================\n";
    connectMsg += "✅ System: Security System\n";
    connectMsg += "📡 IP Address: " + WiFi.localIP().toString() + "\n";
    connectMsg += "📶 Signal Strength: " + String(WiFi.RSSI()) + " dBm\n";
    connectMsg += "📶 WiFi SSID: " + String(ssid) + "\n";
    connectMsg += "🔋 MAC Address: " + macAddress + "\n";
    connectMsg += "🕐 Local Time: " + timeString + "\n";
    connectMsg += "⏰ Uptime: " + String(millis() / 1000) + " seconds\n";
    connectMsg += "☁️ Firebase: Connected\n";
    connectMsg += "=========================\n";
    connectMsg += "System is now online and monitoring.\n";
    connectMsg += "Type /start for commands.";
    
    // Send message
    bool sent = bot.sendMessage(CHAT_ID, connectMsg, "");
    
    if (sent) {
        Serial.println("Connection notification sent to Telegram.");
        connectionNotified = true;
        
        // Wait a bit before sending test photo
        delay(2000);
        
        // Send a test photo to verify camera is working
        Serial.println("Sending test photo...");
        sendPhotoTelegram("📸 Test photo - System connected successfully!");
        
    } else {
        Serial.println("Failed to send connection notification.");
    }
}

// SAFE REBOOT FUNCTION
void safeReboot() {
    Serial.println("\n⚠️ Preparing for system reboot...");
    
    // Send final status to Firebase
    sendToFirebase("system_reboot");
    
    // Set reboot flag in EEPROM
    EEPROM.write(EEPROM_REBOOT_FLAG_ADDR, 1);
    EEPROM.commit();
    
    // Send final message
    bot.sendMessage(CHAT_ID, "🔄 System rebooting now...", "");
    
    // Wait for message to be sent
    delay(2000);
    
    Serial.println("Rebooting in 3 seconds...");
    delay(3000);
    
    ESP.restart();
}

// ===== FIREBASE FUNCTIONS =====
String createFirebaseJson(String eventType, String faceName, bool faceDetected) {
    StaticJsonDocument<512> doc;
    
    // Get current time if available
    struct tm timeinfo;
    String timeString = "";
    if (getLocalTime(&timeinfo)) {
        char buffer[30];
        strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
        timeString = String(buffer);
    } else {
        timeString = String(millis());
    }
    
    doc["device_id"] = "ESP32_CAM";
    doc["timestamp"] = timeString;
    doc["unix_time"] = millis() / 1000;
    doc["distance"] = getDistance();
    doc["vibration"] = digitalRead(VIBRATION_PIN) == LOW;
    doc["door_open"] = doorServo.read() == DOOR_OPEN_ANGLE;
    doc["system_active"] = systemActive;
    doc["face_detected"] = faceDetected;
    doc["face_name"] = faceName;
    doc["camera_angle"] = panPositions[currentPanIndex];
    doc["event_type"] = eventType;
    doc["wifi_strength"] = WiFi.RSSI();
    doc["ip_address"] = WiFi.localIP().toString();
    doc["uptime"] = millis() / 1000;
    
    String jsonString;
    serializeJson(doc, jsonString);
    return jsonString;
}

void sendToFirebase(String eventType, String faceName, bool faceDetected) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected, skipping Firebase update");
        return;
    }
    
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure(); // Use this for HTTPS without certificate verification
    
    String jsonData = createFirebaseJson(eventType, faceName, faceDetected);
    
    // Send to multiple Firebase paths
    
    // 1. Send to sensor_data collection
    String url1 = "https://" + String(FIREBASE_HOST) + "/sensor_data.json";
    http.begin(client, url1);
    http.addHeader("Content-Type", "application/json");
    
    Serial.print("Sending to Firebase (sensor_data): ");
    Serial.println(eventType);
    
    int httpCode1 = http.POST(jsonData);
    if (httpCode1 == HTTP_CODE_OK) {
        Serial.println("Firebase sensor_data updated successfully");
    } else {
        Serial.print("Firebase sensor_data error: ");
        Serial.println(httpCode1);
    }
    http.end();
    
    // 2. Update latest data for this device
    String url2 = "https://" + String(FIREBASE_HOST) + "/devices/ESP32_CAM/latest.json";
    http.begin(client, url2);
    http.addHeader("Content-Type", "application/json");
    
    int httpCode2 = http.PUT(jsonData);
    if (httpCode2 == HTTP_CODE_OK) {
        Serial.println("Firebase latest data updated");
    } else {
        Serial.print("Firebase latest data error: ");
        Serial.println(httpCode2);
    }
    http.end();
    
    // 3. Add to history with timestamp as key
    // Create a timestamp-safe key
    String timestampKey = String(millis());
    String url3 = "https://" + String(FIREBASE_HOST) + "/history/ESP32_CAM/" + timestampKey + ".json";
    http.begin(client, url3);
    http.addHeader("Content-Type", "application/json");
    
    int httpCode3 = http.PUT(jsonData);
    if (httpCode3 == HTTP_CODE_OK) {
        // Success
    }
    http.end();
}

void sendSystemStatusToFirebase() {
    if (WiFi.status() != WL_CONNECTED) {
        return;
    }
    
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();
    
    StaticJsonDocument<256> doc;
    
    doc["online"] = true;
    doc["last_seen"] = millis() / 1000;
    doc["wifi_strength"] = WiFi.RSSI();
    doc["ip_address"] = WiFi.localIP().toString();
    doc["uptime"] = millis() / 1000;
    doc["firmware_version"] = "2.0.0";
    doc["free_heap"] = ESP.getFreeHeap();
    
    String jsonData;
    serializeJson(doc, jsonData);
    
    String url = "https://" + String(FIREBASE_HOST) + "/devices/ESP32_CAM/status.json";
    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");
    
    int httpCode = http.PUT(jsonData);
    if (httpCode == HTTP_CODE_OK) {
        Serial.println("Firebase system status updated");
    } else {
        Serial.print("Firebase status error: ");
        Serial.println(httpCode);
    }
    http.end();
}

void loop() {
    // Handle Telegram commands
    if (millis() > lastTimeBotRan + botRequestDelay) {
        // Skip processing commands for a few seconds after reboot
        if (!rebootFlag || (millis() - rebootTime > rebootDelay)) {
            int numNewMessages = bot.getUpdates(bot.last_message_received + 1);
            while (numNewMessages) {
                handleNewMessages(numNewMessages);
                numNewMessages = bot.getUpdates(bot.last_message_received + 1);
            }
        }
        lastTimeBotRan = millis();
    }
    
    // Clear reboot flag after delay
    if (rebootFlag && (millis() - rebootTime > rebootDelay)) {
        rebootFlag = false;
        Serial.println("Reboot protection period ended");
    }
    
    // Handle manual photo requests
    if (sendPhoto) {
        Serial.println("Manual photo request...");
        sendPhotoTelegram("Manual capture");
        sendPhoto = false;
    }
    
    // Check WiFi reconnection and send notification if reconnected
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi disconnected! Attempting to reconnect...");
        WiFi.reconnect();
        delay(5000);
        
        if (WiFi.status() == WL_CONNECTED && !connectionNotified) {
            Serial.println("WiFi reconnected!");
            sendConnectionNotification();
            // Send reconnection status to Firebase
            sendToFirebase("system_reconnect");
            sendSystemStatusToFirebase();
        }
    }
    
    // Main security logic
    processSecurityCycle();
    
    // Check vibration sensor (independent from security system)
    checkVibrationSensor();
    
    // Send periodic updates to Firebase
    if (millis() - lastFirebaseUpdate >= FIREBASE_UPDATE_INTERVAL) {
        lastFirebaseUpdate = millis();
        sendToFirebase("status");
        sendSystemStatusToFirebase();
        Serial.println("Periodic Firebase update sent");
    }
    
    delay(50);
}

// VIBRATION DETECTION SYSTEM
void checkVibrationSensor() {
    // Check vibration sensor at regular intervals
    if (millis() - lastVibrationCheck >= VIBRATION_CHECK_INTERVAL) {
        lastVibrationCheck = millis();
        
        bool currentVibrationState = digitalRead(VIBRATION_PIN);
        
        // Vibration sensor is active LOW (triggers when LOW)
        if (currentVibrationState == LOW) {
            // Vibration detected
            vibrationDetectionCount++;
            
            // Check if we have enough consecutive detections
            if (vibrationDetectionCount >= VIBRATION_THRESHOLD && !vibrationAlertCooldown) {
                sendVibrationAlert();
                vibrationAlertCooldown = true;
                lastVibrationAlert = millis();
                vibrationDetectionCount = 0;
                
                // Send vibration alert to Firebase
                sendToFirebase("vibration");
            }
        } else {
            // No vibration - reset counter
            vibrationDetectionCount = 0;
        }
        
        lastVibrationState = currentVibrationState;
    }
    
    // Reset cooldown after specified time
    if (vibrationAlertCooldown && millis() - lastVibrationAlert >= VIBRATION_DEBOUNCE_TIME) {
        vibrationAlertCooldown = false;
    }
}

void sendVibrationAlert() {
    Serial.println("\n🔔🔔🔔 VIBRATION DETECTED! 🔔🔔🔔");
    Serial.println("--------------------------------------");
    
    // Get current time if available
    struct tm timeinfo;
    String timeString = "Not available";
    if (getLocalTime(&timeinfo)) {
        char buffer[20];
        strftime(buffer, sizeof(buffer), "%H:%M:%S", &timeinfo);
        timeString = String(buffer);
    }
    
    // Send Telegram alert
    String vibrationMsg = "🔔 VIBRATION DETECTED!\n";
    vibrationMsg += "Time: " + timeString + "\n";
    vibrationMsg += "System uptime: " + String(millis() / 1000) + " seconds\n";
    vibrationMsg += "⚠️ System is being tampered with!\n";
    vibrationMsg += "Check camera feed for suspicious activity.";
    
    bot.sendMessage(CHAT_ID, vibrationMsg, "");
    
    // Take photo of the area
    Serial.println("Taking photo of vibration area...");
    sendPhotoTelegram("🔔 Vibration detected - Possible tampering");
    
    // Short alert beep (different from intruder alarm)
    for (int i = 0; i < 3; i++) {
        digitalWrite(BUZZER_PIN, HIGH);
        delay(100);
        digitalWrite(BUZZER_PIN, LOW);
        delay(100);
    }
    
    Serial.println("Vibration alert sent to Telegram.");
}

// SECURITY LOGIC
void processSecurityCycle() {
    static unsigned long lastDistanceCheck = 0;
    const unsigned long distanceCheckInterval = 500;
    
    if (millis() - lastDistanceCheck >= distanceCheckInterval) {
        lastDistanceCheck = millis();
        
        float distance = getDistance();
        
        if (!systemActive && distance > 0 && distance < MAX_DISTANCE) {
            // Object detected - activate system
            systemActive = true;
            faceSearchMode = true;
            captureAttempts = 0;
            
            Serial.println("\n-----------------------------------");
            Serial.println("OBJECT DETECTED! Activating system...");
            Serial.print("Distance: ");
            Serial.print(distance);
            Serial.println(" cm");
            Serial.println("-------------------------------------");
            
            // Send Telegram alert
            String alertMsg = "⚠️ Motion detected! Distance: " + String(distance, 1) + " cm";
            bot.sendMessage(CHAT_ID, alertMsg, "");
            
            // Send motion detection to Firebase
            sendToFirebase("motion");
            
            // Short beep
            triggerAlert(false);
        }
    }
    
    if (systemActive && faceSearchMode) {
        Serial.println("Capturing image for face detection...");
        
        // Capture image
        camera_fb_t *fb = esp_camera_fb_get();
        if (!fb) {
            Serial.println("Camera capture failed!");
            delay(1000);
            return;
        }
        
        // Send to face recognition server
        Serial.println("Sending to face recognition server...");
        String serverResponse = sendToFaceRecognitionServer(fb);
        
        // Parse JSON response
        DynamicJsonDocument doc(1024);
        DeserializationError error = deserializeJson(doc, serverResponse);
        
        if (!error) {
            int facesDetected = doc["faces_detected"] | 0;
            bool authorized = doc["authorized"] | false;
            String name = doc["name"] | "Unknown";
            float confidence = doc["confidence"] | 0.0;
            
            if (facesDetected > 0) {
                if (authorized) {
                    // AUTHORIZED PERSON
                    Serial.println("\n✅✅✅ AUTHORIZED PERSON DETECTED ✅✅✅");
                    Serial.print("Name: ");
                    Serial.println(name);
                    Serial.print("Confidence: ");
                    Serial.println(confidence, 3);
                    
                    // Get current time
                    struct tm timeinfo;
                    String timeString = "";
                    if (getLocalTime(&timeinfo)) {
                        char buffer[20];
                        strftime(buffer, sizeof(buffer), "%H:%M:%S", &timeinfo);
                        timeString = String(buffer);
                    }
                    
                    // Send Telegram
                    String msg = "✅ ACCESS GRANTED!\n";
                    msg += "Time: " + timeString + "\n";
                    msg += "Person: " + name + "\n";
                    msg += "Confidence: " + String(confidence, 3) + "\n";
                    msg += "Door: Opening for 5 seconds";
                    bot.sendMessage(CHAT_ID, msg, "");
                    
                    // Send face recognition to Firebase
                    sendToFirebase("face", name, true);
                    
                    // Open door
                    openDoor();
                    
                    // Friendly beep
                    triggerAlert(false);
                    
                    // Send photo to Telegram
                    sendPhotoTelegram("✅ Access granted: " + name);
                    
                    // Wait, then close door
                    delay(5000);
                    closeDoor();
                    
                    // Send door status to Firebase
                    sendToFirebase("door_closed");
                    
                    // Send door closed notification
                    bot.sendMessage(CHAT_ID, "🚪 Door closed automatically.", "");
                    
                    // Reset system
                    systemActive = false;
                    faceSearchMode = false;
                    panServo.write(panPositions[0]);
                    
                } else {
                    // INTRUDER ALERT
                    Serial.println("\n🚨🚨🚨 INTRUDER ALERT! 🚨🚨🚨");
                    
                    // Get current time
                    struct tm timeinfo;
                    String timeString = "";
                    if (getLocalTime(&timeinfo)) {
                        char buffer[20];
                        strftime(buffer, sizeof(buffer), "%H:%M:%S", &timeinfo);
                        timeString = String(buffer);
                    }
                    
                    // Send Telegram
                    String alertMsg = "🚨 INTRUDER DETECTED!\n";
                    alertMsg += "Time: " + timeString + "\n";
                    alertMsg += "Camera Position: " + String(panPositions[currentPanIndex]) + "°\n";
                    alertMsg += "System: Activating alarm for 10 seconds!";
                    bot.sendMessage(CHAT_ID, alertMsg, "");
                    
                    // Send intruder alert to Firebase
                    sendToFirebase("face", "Intruder", true);
                    
                    // Send photo
                    sendPhotoTelegram("🚨 INTRUDER ALERT!");
                    
                    // Trigger alarm
                    triggerAlert(true);
                    
                    // Reset after alarm
                    delay(10000);
                    systemActive = false;
                    faceSearchMode = false;
                    panServo.write(panPositions[0]);
                    
                    // Send alarm deactivated message
                    bot.sendMessage(CHAT_ID, "🔕 Alarm deactivated. System reset.", "");
                }
            } else {
                // No face detected - rotate camera
                Serial.println("No face detected. Rotating camera...");
                captureAttempts++;
                
                if (captureAttempts < NUM_PAN_POSITIONS) {
                    currentPanIndex = (currentPanIndex + 1) % NUM_PAN_POSITIONS;
                    panServo.write(panPositions[currentPanIndex]);
                    delay(800);
                    
                    // Send camera position update to Firebase
                    sendToFirebase("camera_move");
                } else {
                    Serial.println("No face found after scanning all positions.");
                    Serial.println("Deactivating system.");
                    
                    // Send no face found message
                    bot.sendMessage(CHAT_ID, "⚠️ No face detected after full scan.\nSystem deactivated.", "");
                    
                    // Send scan complete to Firebase
                    sendToFirebase("scan_complete");
                    
                    systemActive = false;
                    faceSearchMode = false;
                    captureAttempts = 0;
                    panServo.write(panPositions[0]);
                }
            }
        } else {
            Serial.println("Failed to parse server response!");
            Serial.println("Error: " + String(error.c_str()));
            bot.sendMessage(CHAT_ID, "❌ Face recognition server error.\nSystem deactivated.", "");
            
            // Send error to Firebase
            sendToFirebase("server_error");
            
            systemActive = false;
            faceSearchMode = false;
            panServo.write(panPositions[0]);
        }
        
        esp_camera_fb_return(fb);
        delay(1000);
    }
}

// FACE RECOGNITION SERVER COMMUNICATION
String sendToFaceRecognitionServer(camera_fb_t *fb) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected!");
        return "{\"error\":\"WiFi not connected\"}";
    }
    
    HTTPClient http;
    http.begin(SERVER_URL);
    http.addHeader("Content-Type", "application/json");
    
    // Convert image to base64 using our function
    String imageBase64 = base64_encode(fb->buf, fb->len);
    
    // Create JSON payload
    DynamicJsonDocument jsonDoc(30000);
    jsonDoc["image"] = imageBase64;
    jsonDoc["device_id"] = "ESP32_CAM";
    jsonDoc["timestamp"] = millis();
    
    String payload;
    serializeJson(jsonDoc, payload);
    
    // Send POST request
    int httpCode = http.POST(payload);
    String response = "{}";
    
    if (httpCode == HTTP_CODE_OK) {
        response = http.getString();
        Serial.print("Server response code: ");
        Serial.println(httpCode);
    } else {
        Serial.print("HTTP Error: ");
        Serial.println(httpCode);
        Serial.println("Check:");
        Serial.println("1. Server is running (python server.py)");
        Serial.println("2. Correct IP in SERVER_URL variable");
        Serial.println("3. Windows Firewall allows port 5000");
        
        response = "{\"error\":\"HTTP " + String(httpCode) + "\"}";
    }
    
    http.end();
    return response;
}

// HARDWARE CONTROL FUNCTIONS
float getDistance() {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    
    long duration = pulseIn(ECHO_PIN, HIGH, 30000);
    if (duration == 0) return -1;
    
    float distance = duration * 0.034 / 2;
    return distance;
}

void LEDFlash_State(bool state) {
    digitalWrite(FLASH_LED_PIN, state);
}

void triggerAlert(bool isIntruder) {
    if (isIntruder) {
        Serial.println("INTRUDER ALARM ACTIVATED!");
        for (int i = 0; i < 15; i++) {
            digitalWrite(BUZZER_PIN, HIGH);
            delay(200);
            digitalWrite(BUZZER_PIN, LOW);
            delay(200);
        }
    } else {
        digitalWrite(BUZZER_PIN, HIGH);
        delay(300);
        digitalWrite(BUZZER_PIN, LOW);
    }
}

void openDoor() {
    Serial.println("Opening door...");
    doorServo.write(DOOR_OPEN_ANGLE);
    delay(1000);
    
    // Send door open to Firebase
    sendToFirebase("door_open");
}

void closeDoor() {
    Serial.println("Closing door...");
    doorServo.write(DOOR_CLOSE_ANGLE);
    delay(1000);
    
    // Send door close to Firebase
    sendToFirebase("door_closed");
}

// TELEGRAM FUNCTIONS
String sendPhotoTelegram(String caption) {
    const char* myDomain = "api.telegram.org";
    String getAll = "";
    String getBody = "";
    
    Serial.println("Taking photo for Telegram...");
    
    bool useFlash = isNightTime();
    if(useFlash) {
        LEDFlash_State(HIGH);
        delay(1000);
    }
    
    camera_fb_t *fb = esp_camera_fb_get();
    if(!fb) {
        Serial.println("Camera capture failed");
        if(useFlash) LEDFlash_State(LOW);
        return "Camera capture failed";
    }
    
    if(useFlash) LEDFlash_State(LOW);
    
    if(clientTCP.connect(myDomain, 443)) {
        String head = "--ESP32CAM\r\nContent-Disposition: form-data; name=\"chat_id\"; \r\n\r\n" + CHAT_ID + "\r\n";
        head += "--ESP32CAM\r\nContent-Disposition: form-data; name=\"caption\"; \r\n\r\n" + caption + "\r\n";
        head += "--ESP32CAM\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"esp32-cam.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n";
        String tail = "\r\n--ESP32CAM--\r\n";
        
        uint32_t imageLen = fb->len;
        uint32_t extraLen = head.length() + tail.length();
        uint32_t totalLen = imageLen + extraLen;
        
        clientTCP.println("POST /bot" + BOTtoken + "/sendPhoto HTTP/1.1");
        clientTCP.println("Host: " + String(myDomain));
        clientTCP.println("Content-Length: " + String(totalLen));
        clientTCP.println("Content-Type: multipart/form-data; boundary=ESP32CAM");
        clientTCP.println();
        clientTCP.print(head);
        
        uint8_t *fbBuf = fb->buf;
        size_t fbLen = fb->len;
        
        for(size_t n = 0; n < fbLen; n += 1024) {
            if(n + 1024 < fbLen) {
                clientTCP.write(fbBuf, 1024);
                fbBuf += 1024;
            } else if(fbLen % 1024 > 0) {
                size_t remainder = fbLen % 1024;
                clientTCP.write(fbBuf, remainder);
            }
        }
        
        clientTCP.print(tail);
        esp_camera_fb_return(fb);
        
        int waitTime = 10000;
        long startTimer = millis();
        boolean state = false;
        
        while((startTimer + waitTime) > millis()) {
            Serial.print(".");
            delay(100);
            while(clientTCP.available()) {
                char c = clientTCP.read();
                if(state) getBody += String(c);
                if(c == '\n') {
                    if(getAll.length() == 0) state = true;
                    getAll = "";
                } else if(c != '\r') {
                    getAll += String(c);
                }
                startTimer = millis();
            }
            if(getBody.length() > 0) break;
        }
        clientTCP.stop();
        Serial.println(getBody);
    }
    
    Serial.println("Photo sent to Telegram");
    return getBody;
}

void handleNewMessages(int numNewMessages) {
    for(int i = 0; i < numNewMessages; i++) {
        String chat_id = String(bot.messages[i].chat_id);
        if(chat_id != CHAT_ID) {
            bot.sendMessage(chat_id, "Unauthorized user", "");
            continue;
        }
        
        String text = bot.messages[i].text;
        String from_name = bot.messages[i].from_name;
        
        if(text == "/start") {
            String welcome = "👋 Welcome " + from_name + "!\n\n";
            welcome += "🔐 Security System\n";
            welcome += "==============================\n";
            welcome += "System Status: " + String(connectionNotified ? "✅ Online" : "❌ Offline") + "\n";
            welcome += "WiFi: " + String(WiFi.status() == WL_CONNECTED ? "✅ Connected" : "❌ Disconnected") + "\n";
            welcome += "IP: " + WiFi.localIP().toString() + "\n";
            welcome += "Signal: " + String(WiFi.RSSI()) + " dBm\n";
            welcome += "Firebase: " + String(FIREBASE_HOST) + "\n";
            welcome += "==============================\n";
            welcome += "📋 Commands:\n";
            welcome += "/photo - Take photo\n";
            welcome += "/status - System status\n";
            welcome += "/door_open - Open door (manual)\n";
            welcome += "/door_close - Close door\n";
            welcome += "/scan - Start face scan\n";
            welcome += "/stop - Stop system\n";
            welcome += "/vibration_test - Test vibration sensor\n";
            welcome += "/reboot - Reboot system (5s delay)\n";
            welcome += "/firebase_test - Test Firebase connection\n";
            welcome += "==============================\n";
            welcome += "System is monitoring for motion and vibration.";
            bot.sendMessage(CHAT_ID, welcome, "");
        }
        else if(text == "/photo") {
            sendPhoto = true;
            bot.sendMessage(CHAT_ID, "📸 Taking photo...", "");
        }
        else if(text == "/status") {
            // Get current time
            struct tm timeinfo;
            String timeString = "Not available";
            if (getLocalTime(&timeinfo)) {
                char buffer[20];
                strftime(buffer, sizeof(buffer), "%Y-%m-d %H:%M:%S", &timeinfo);
                timeString = String(buffer);
            }
            
            String status = "📊 SYSTEM STATUS\n";
            status += "=================\n";
            status += "🕐 Time: " + timeString + "\n";
            status += "⏰ Uptime: " + String(millis() / 1000) + " seconds\n";
            status += "📡 WiFi: " + String(WiFi.status() == WL_CONNECTED ? "✅ Connected" : "❌ Disconnected") + "\n";
            status += "📶 RSSI: " + String(WiFi.RSSI()) + " dBm\n";
            status += "📍 IP: " + WiFi.localIP().toString() + "\n";
            status += "🎥 Camera: " + String(systemActive ? "🔴 Active" : "🟢 Idle") + "\n";
            status += "🚪 Door: " + String(doorServo.read() == DOOR_OPEN_ANGLE ? "Open" : "Closed") + "\n";
            status += "📏 Distance: " + String(getDistance(), 1) + " cm\n";
            status += "🎯 Camera Pos: " + String(panPositions[currentPanIndex]) + "°\n";
            status += "🔔 Vibration: " + String(digitalRead(VIBRATION_PIN) == LOW ? "⚠️ Detected" : "✅ Normal") + "\n";
            status += "⏳ Vibration Cooldown: " + String(vibrationAlertCooldown ? "Yes" : "No") + "\n";
            status += "🔁 Reboot Protection: " + String(rebootFlag ? "Active" : "Inactive") + "\n";
            status += "☁️ Firebase: " + String(FIREBASE_HOST) + "\n";
            status += "=================\n";
            status += "Face Mode: " + String(faceSearchMode ? "Active" : "Inactive");
            bot.sendMessage(CHAT_ID, status, "");
        }
        else if(text == "/door_open") {
            openDoor();
            bot.sendMessage(CHAT_ID, "🚪 Door opened manually", "");
        }
        else if(text == "/door_close") {
            closeDoor();
            bot.sendMessage(CHAT_ID, "🚪 Door closed manually", "");
        }
        else if(text == "/scan") {
            systemActive = true;
            faceSearchMode = true;
            captureAttempts = 0;
            bot.sendMessage(CHAT_ID, "🔍 Starting manual face scan...", "");
            sendToFirebase("manual_scan");
        }
        else if(text == "/stop") {
            systemActive = false;
            faceSearchMode = false;
            panServo.write(panPositions[0]);
            bot.sendMessage(CHAT_ID, "🛑 System stopped", "");
            sendToFirebase("system_stopped");
        }
        else if(text == "/vibration_test") {
            // Manually trigger vibration alert for testing
            sendVibrationAlert();
            bot.sendMessage(CHAT_ID, "🔔 Vibration test triggered", "");
        }
        else if(text == "/reboot") {
            // Use safe reboot function
            safeReboot();
        }
        else if(text == "/firebase_test") {
            // Test Firebase connection
            sendToFirebase("firebase_test");
            sendSystemStatusToFirebase();
            bot.sendMessage(CHAT_ID, "☁️ Firebase test triggered", "");
        }
        else {
            bot.sendMessage(CHAT_ID, "❓ Unknown command. Type /start for available commands.", "");
        }
    }
}

bool isNightTime() {
    struct tm timeinfo;
    if(!getLocalTime(&timeinfo)) return false;
    
    int hour = timeinfo.tm_hour;
    return (hour >= 18 || hour < 6);
}

void configInitCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sscb_sda = SIOD_GPIO_NUM;
    config.pin_sscb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;
    
    if(psramFound()) {
        config.frame_size = FRAMESIZE_VGA;
        config.jpeg_quality = 12;
        config.fb_count = 2;
    } else {
        config.frame_size = FRAMESIZE_SVGA;
        config.jpeg_quality = 12;
        config.fb_count = 1;
    }
    
    esp_err_t err = esp_camera_init(&config);
    if(err != ESP_OK) {
        Serial.printf("Camera init failed: 0x%x", err);
        delay(1000);
        ESP.restart();
    }
    
    sensor_t *s = esp_camera_sensor_get();
    s->set_framesize(s, FRAMESIZE_VGA);
    s->set_contrast(s, 2);
}