FROM louislam/uptime-kuma:1

# Install comprehensive debugging tools
USER root
RUN apt-get update && \
    apt-get install -y \
        postgresql-client \
        netcat-openbsd \
        bash \
        procps \
        net-tools \
        dnsutils \
        iputils-ping \
        traceroute \
        curl \
        telnet && \
    rm -rf /var/lib/apt/lists/*

# Copy and prepare initialization script
COPY init-db.sh /app/
RUN chmod +x /app/init-db.sh

# Ensure bash is used and variables are preserved
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV=/etc/profile

# Enhanced logging
ENV NODE_OPTIONS="--trace-warnings --trace-deprecation"
ENV DEBUG="*"
ENV LOG_LEVEL="debug"

# Use the init script as entrypoint with debugging
ENTRYPOINT ["/bin/bash", "-c", "/app/init-db.sh"]
