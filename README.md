# UNO Q MyCard

A business card detection and recognition demo powered by **Arduino UNO Q**, combining Edge AI with Cloud AI.

The project demonstrates how to build an AI-powered application using camera input, on-device card detection, cloud-based business card information extraction, and LED Matrix status feedback.

## Architecture

```text
USB Camera
   |
   v
FFmpeg (Camera Stream)
   |
   v
MyCardOS (React Web UI)
   |
   +-- Vision (Edge AI / QuadScan)
   |      |
   |      +-- Business Card Detection
   |      +-- Corner Detection
   |
   +-- Image Capture
   |      |
   |      v
   |   Cloud AI (Gemma 4)
   |      |
   |      v
   |   Business Card Information
   |
   +-- MCU (Arduino Bridge)
          |
          v
       LED Matrix (Status Display)
```

## Components

| Component | Description | Port |
|---|---|---|
| MyCardOS | React-based web interface | 58080 |
| Vision | Business card detection API | 18081 |
| FFmpeg | USB camera streaming service | 58081 (localhost) |
| MCU | LED Matrix status display via Arduino Bridge | Unix Socket |
| Cloud AI | Gemma 4 image understanding | External API |

### Repositories

- [mycardos](https://github.com/Mighty-Net/uno-q-mycardos)
- [vision](https://github.com/Mighty-Net/uno-q-mycard_vision)

Both projects are managed as Git Submodules.

### MCU

The MCU component controls the onboard LED Matrix of the Arduino UNO Q.

It uses FastAPI and Arduino Bridge to communicate with the microcontroller and display predefined LED patterns representing different application states.

## Requirements

- Arduino UNO Q
- USB UVC-compatible camera
- Docker Engine with Rootless Docker configured
- Docker Compose V2
- Git
- Internet connectivity for Cloud AI recognition

## Installation

### 1. Clone Repository

```bash
git clone git@github.com:Mighty-Net/uno-q-mycard_integrate.git
cd uno-q-mycard_integrate
```

### 2. Run Setup

```bash
bash setup.sh
```

The setup script will:

- Initialize Git Submodules.
- Create `configure.conf` from `configure.conf.default`.
- Create `docker-compose.yml` from `docker-compose.yml.default`.
- Create `update.sh` from `update.sh.default`.

Existing configuration files will not be overwritten.

### 3. Configure Camera and Cloud AI

Edit the configuration file:

```bash
nano configure.conf
```

Example:

```ini
CAMERA_ID=<YOUR_CAMERA_ID>
AIAPIURL=<YOUR_API_URL>
AIAPIKEY=<YOUR_API_KEY>
```

#### Find Your Camera ID

Connect your USB camera and execute:

```bash
ls -l /dev/v4l/by-id/
```

Example output:

```text
usb-046d_C270_HD_WEBCAM_200901010001-video-index0 -> ../../video0
```

Copy the filename into `configure.conf`:

```ini
CAMERA_ID=usb-046d_C270_HD_WEBCAM_200901010001-video-index0
```

Use a device that supports Video Capture. The camera ID depends on the connected hardware.

The Cloud AI API settings must be obtained from the service administrator.

### 4. Start Services

```bash
docker --context rootless compose up -d --build
```

Check container status:

```bash
docker --context rootless compose ps
```

### 5. Open MyCardOS

Open your browser:

```text
http://<UNO_Q_IP>:58080
```

Replace `<UNO_Q_IP>` with the IP address of your UNO Q.

## Update

Run:

```bash
bash update.sh
```

The update script pulls updates for MyCardOS and Vision, then rebuilds and restarts the Docker services.

Local uncommitted changes are not intentionally discarded. If Git encounters conflicting changes or diverged branches, manual intervention may be required.

## Project Structure

```text
mycard_integrate/
├── docker/
│   └── ffmpeg/
├── src/
│   ├── mycardos/          # Git Submodule
│   ├── vision/            # Git Submodule
│   └── mcu/               # MCU API and Arduino Sketch
│       └── sketch/        # Arduino MCU Firmware
├── media/
├── log/
├── .gitmodules
├── .gitignore
├── configure.conf.default
├── docker-compose.yml.default
├── setup.sh
└── update.sh.default
```

## Development

The default Docker Compose configuration includes source-code bind mounts for development.

This allows developers to modify local source files without pushing changes to GitHub first. Depending on the service, restarting or rebuilding the container may still be required.

For production deployment, review and remove development-only source mounts.

## Notes

- Camera capture and business card detection run locally on UNO Q.
- Cloud AI recognition requires network connectivity and valid API credentials.
- The MCU controls the onboard LED Matrix to display different application states.
- Actual recognition accuracy depends on camera focus, image quality, lighting, and card layout.
- Rootless Docker must be configured before deploying the application.

## License

This project is licensed under the MIT License.

See [LICENSE](LICENSE) for details.