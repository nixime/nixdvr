# Security Camera DVR
This set of scripts is intended to enable recording network based security cameras. 

The recorder will break the recordings up into small segements throughout the day. This will help prevent crashes or network outages from affecting to large of a recording. These segements will then be combined into a single day file on a periodic basis.

The scripts will also ensure that old days and segements are cleaned up on a periodic basis.

This repository can support the system running as a docker image, or as a systemd service.

## Folder Structure
The code has been broken up into 3 seperate high level folders to enable easier maintanence and setup.

The files contained within the "container" folder structure are specific to running the application code within a container. 

The files contained within the "src" folder structure are the nuts and bolts of the application.

The files contained within the "systemd" folder are used to enable running the application as a systemd service.

# Installation (Systemd)
Each camera requries a seperate systemd service running for recording. Cleanup and merging only require a single service instance, and will process all camera files.

## Scripts
```
COPY src/nixdvr_merge /usr/local/bin/nixdvr_merge
COPY src/nixdvr_record /usr/local/bin/nixdvr_record
COPY src/nixdvr_cleanup /usr/local/bin/nixdvr_cleanup
```

## Installing File Merger
```
COPY systemd/nixdvr-merge.service /etc/systemd/system/nixdvr-merge.service
COPY systemd/nixdvr-merge.timer /etc/systemd/system/nixdvr-merge.timer

systemctl enable nixdvr-merge.timer
```

## Installing Cleanup Utility
```
COPY systemd/nixdvr-cleanup.service /etc/systemd/system/nixdvr-cleanup.service
COPY systemd/nixdvr-cleanup.timer /etc/systemd/system/nixdvr-cleanup.timer

systemctl enable nixdvr-cleanup.timer
```

## Installing Recording Agent
```
COPY systemd/nixdvr-agent@.service nixdvr-agent@.service /etc/systemd/system/nixdvr-agent@.service
```

### Global Configuration
```
MKDIR /etc/nixdvr.d
COPY container/nixdvr.cfg /etc/nixdvr.cfg
```
| KEY | Description |
| --- | ----------- |
|ConfigDir | Location of the configuration directory. "/etc/nixdvr.d" is the default |
|StorageDir | Location where the videos should be stored. A new directory for each camera will be created within this directory |
|SegmentSize_s | Size of each segment in seconds. |
|StorageAgeTemp | Age of the files in days that should be kept in temporary storage. This can aid in debuggin and loss of data if something goes wrong. |
|StorageAge | Maximum age of files that should be kept in days. Once reached files older than this value will be deleted.|

### Camera Configuration
You need a seperate camera.cfg for each camera you want recording. You can name the files as you want, but camera names are helpful. The commands below use "camera1" as the name, duplicate each of these steps as necessary.

```
COPY container/camera.cfg /etc/nixdvr.d/camera1.cfg
systemctl enable nixdvr-agent@camera1.service
systemctl start nixdvr-agent@camera1.service
```
| KEY | Description |
| --- | ----------- |
| STREAM_NAME | Name of the camera and folder that should be used. This doesn't have to match the config name, but it is helpful. If not provided then the config file name is used as the STREAM_NAME value. |
| STREAM_URL | URL of the camera that should be recofded. |


# Installation (Docker)
## Build
```
docker build --rm -t nixdvr:nightly .
```
## Run
```
docker run \
    --name 'nixdvr_camera1' \
    -v /etc/timezone:/etc/timezone:ro \  
    -v /etc/localtime:/etc/localtime:ro \
    -v /host/dir/media:/media \
    -e STREAM_URL="rtsp:/x.y.z.a/" \
    -e STREAM_NAME=camera1 \
    nixdvr:nightly
```

## Podman Running on Startup (non-root)
```
podman generate systemd --new --name nixdvr_camera1 -f
mkdir -p ~/.config/systemd/user
mv container-nixdvr_camera1.service ~/.config/systemd/user
sudo systemctl daemon-reload
systemctl --user daemon-reload
systemctl --user enable container-nixdvr_camera1.service
sudo loginctl enable-linger
```

## Systemd Script
Due to some weirdness, it is advised to update your systemd file with the additional lines below. This seems to ensure the process will restart if the recorder or other items fails (network issues)

```
[Unit]
StartLimitIntervalSec=400
StartLimitBurst=5

[Service]
Restart=always
RestartSec=90
```

# Notes
Jelly works as a good viewer if you set it up to point to your video folder. slight delay, but not meant to be realtime.

Don't forget to modify your storage settings in docker so you don't fill up with log files or othing things.

When setting up systemd services it is advised ot ensure restarting on failure is choosen. The apps will attempt recovery, but prolonged network issues may cause them to stop functioning.
