# 🔒 SecuritySystem: Multi-Platform Security Solution

A robust security system integrating **hardware components**, a **Python backend**, a **web dashboard**, and a **mobile application**, providing comprehensive monitoring and control.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-Unlicensed-red)
![Stars](https://img.shields.io/github/stars/hedi0/SecuritySystem?style=social)
![Forks](https://img.shields.io/github/forks/hedi0/SecuritySystem?style=social)

![Project Cover](/sec_cover.png)

---

## ✨ Features

- 📱 **Mobile App:** Monitor and control via Flutter app.
- 🖥️ **Web Dashboard:** Real-time overview of all devices and alerts.
- 🔗 **Hardware Integration:** Communicate with components using CH34x serial driver.
- ⚡ **Real-Time Alerts:** Instant notifications for anomalies or breaches.
- ⚙️ **Modular & Extensible:** Python and Dart code designed for customization and scaling.

---

## 🛠️ Installation Guide

### Prerequisites

- Python 3.x  
- Flutter SDK  
- Git  
- Optional: **Proteus** or hardware simulation for testing devices

### Clone Repository

```bash
git clone https://github.com/hedi0/SecuritySystem.git
cd SecuritySystem
```

### Install CH34x Driver (Windows)

```bash
./CH34x_Install_Windows_v3_4.EXE
```
Follow prompts to complete installation.

### Setup Python Backend

```bash
cd code/server
pip install -r requirements.txt
python server.py
```
- Default URL: `http://localhost:5000`

### Setup Flutter App

```bash
cd Flutter\ App
flutter pub get
flutter run
```

### Access Web Dashboard

- Open: `http://localhost:5000/dashboard.html`

> ⚠️ Mak

---

## 💡 Usage Example

1. **Start Python server** → serves web dashboard & backend API.  
2. **Run Flutter app** → connect to server.  
3. **Monitor dashboard** → real-time alerts & device statuses.

---

## ⚙️ Configuration Options

| Option | Description | Default | Type |
|--------|-------------|--------|------|
| `PORT` | Backend server port | 5000 | int |
| `SERIAL_PORT` | Hardware serial port | COM3 | string |
| `BAUD_RATE` | Serial communication speed | 9600 | int |
| `ALERT_EMAIL` | Email for notifications | null | string |
| `DASHBOARD_REFRESH` | Dashboard refresh interval (s) | 5 | int |

---

## 🗺️ Roadmap

- **v1.1:** User authentication & authorization  
- **v1.2:** Support additional sensors (motion, temperature, smoke)  
- **v1.3:** AI/ML anomaly detection  
- **Future:** Third-party API integration, UI/UX enhancements
