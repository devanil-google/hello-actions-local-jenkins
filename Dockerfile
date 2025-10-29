# Use a stable Python slim image
FROM python:3.10-slim-bookworm

LABEL maintainer="example@example.com" \
      description="Lightweight Python image around 1.5 GB in size"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system libraries (~200–300 MB)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    liblapack-dev \
    libblas-dev \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages (~900 MB)
RUN pip install --no-cache-dir \
    numpy \
    pandas \
    scipy \
    matplotlib \
    seaborn \
    scikit-learn \
    flask \
    requests \
    opencv-python-headless \
    pillow

# Optional filler to reach ~1.5 GB
RUN mkdir -p /opt/filler && dd if=/dev/zero of=/opt/filler/pad.bin bs=1M count=200

WORKDIR /app
COPY . /app

CMD ["python", "-c", "print('Image built successfully (~1.5 GB).')"]
