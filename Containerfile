FROM debian:bookworm

#
# Install the necessary components to make the DVR work
# then delete all the APT libraries to clean things up and prevent 
# accidental installations.
RUN apt update
RUN apt install -y --no-install-recommends \
    cron \
    supervisor \
    ffmpeg
RUN rm -rf /var/lib/apt/lists/*
RUN apt clean

#
# Setup folders needed
#
RUN mkdir -p /etc/nixdvr.d
RUN mkdir -p /media

#
# Setup our APP files
#
## configuration files
COPY conf/container/nixdvr.cfg /etc/nixdvr.cfg
COPY conf/container/camera.cfg /etc/nixdvr.d/camera.cfg
## application files
COPY src/nixdvr_merge.sh /usr/local/bin/nixdvr_merge
COPY src/nixdvr_record.sh /usr/local/bin/nixdvr_record
COPY src/nixdvr_cleanup.sh /usr/local/bin/nixdvr_cleanup
COPY src/container/run.sh /usr/local/bin/run.sh

RUN chmod 555 /usr/local/bin/nixdvr_merge
RUN chmod 555 /usr/local/bin/nixdvr_record
RUN chmod 555 /usr/local/bin/nixdvr_cleanup
RUN chmod 555 /usr/local/bin/run.sh

#
# Setup our CRON jobs
#
COPY conf/container/crontab /etc/cron.d/timers
RUN chmod 0644 /etc/cron.d/timers
RUN crontab /etc/cron.d/timers

#
# Setup our SUPERVISOR
# 
COPY conf/container/supervisord.conf /etc/supervisor/

#
# Setup ENVIRONMENT variables
#
ENV STREAM_URI=rstp:/1.1.1.1
ENV STREAM_NAME=camera

# Use systemd as command
CMD [ "/usr/local/bin/run.sh" ]