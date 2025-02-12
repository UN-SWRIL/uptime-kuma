FROM louislam/uptime-kuma:1

USER root

# Install netcat for database connection check
RUN apt-get update && apt-get install -y netcat-openbsd

# Copy initialization script
COPY init-db.sh .
RUN chmod +x init-db.sh && \
    chown -R kuma:kuma /app

USER kuma

# Use the init script as entrypoint
ENTRYPOINT ["./init-db.sh"]

# Ensure environment variables are available
ENV DB_TYPE=$DB_TYPE
ENV DB_HOST=$DB_HOST
ENV DB_PORT=$DB_PORT
ENV DB_USER=$DB_USER
ENV DB_NAME=$DB_NAME
ENV DB_PASSWORD=$DB_PASSWORD 