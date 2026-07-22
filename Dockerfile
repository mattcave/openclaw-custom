FROM alpine/openclaw:latest

USER root

# System dependencies required by clawarr-suite and general skill scripts
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    bc \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

npm install -g openclaw@2026.7.1-2

# Python packages required by skill scripts
RUN pip3 install --no-cache-dir --break-system-packages requests

# Local audio transcription (faster-whisper)
RUN pip3 install --no-cache-dir --break-system-packages "faster-whisper" "numpy<2.0"

RUN printf '#!/usr/bin/env python3\nimport sys\nfrom faster_whisper import WhisperModel\nmodel = WhisperModel("base", device="cpu", compute_type="int8")\nsegments, _ = model.transcribe(sys.argv[1])\nprint("".join(s.text for s in segments).strip())\n' \
    > /usr/local/bin/faster-whisper-transcribe && \
    chmod +x /usr/local/bin/faster-whisper-transcribe
    
# Fix npm global prefix so the `node` user can install global packages
# without permission errors (avoids the /root vs /home/node mismatch).
# Using an env var instead of `npm config set` avoids ending up with a
# stale/incorrect prefix baked into ~/.npmrc under the wrong user.
ENV NPM_CONFIG_PREFIX="/home/node/.npm-global"
ENV PATH="/home/node/.npm-global/bin:${PATH}"
RUN mkdir -p /home/node/.npm-global && chown -R node:node /home/node/.npm-global

USER node

# Install pinned version of openclaw temporarily
RUN npm install -g openclaw@2026.7.1-2

# Install clawhub globally as the node user, using the corrected prefix
RUN npm install -g clawhub

# Drop back to root only long enough for entrypoint needs; the base image's
# own entrypoint/tini setup already handles dropping privileges correctly,
# so we don't override USER again here — inherits whatever the base image sets.
