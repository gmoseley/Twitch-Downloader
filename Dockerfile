FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir --upgrade yt-dlp

WORKDIR /app
COPY vod-downloader.py .

ENV VOD_STORAGE_ROOT=/data/storage \
    VOD_STATE_DIR=/data/state \
    VOD_PORT=8787 \
    VOD_BIND_HOST=0.0.0.0

VOLUME ["/data"]
EXPOSE 8787

CMD ["python3", "vod-downloader.py"]
