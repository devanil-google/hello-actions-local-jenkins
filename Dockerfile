# This base image is very old and has known critical vulnerabilities.
# This is *intended* to fail the scan for Test Scenario 2.
FROM ubuntu:16.04

# Add a dummy command to make it a "real" image
LABEL maintainer="test@example.com"
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
 && rm -rf /var/lib/apt/lists/*

CMD ["echo", "This is a vulnerable image."]
