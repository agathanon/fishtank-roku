FROM python:3.12-slim

RUN groupadd -g 1001 telemetry && \
    useradd -u 1001 -g 1001 -m -s /bin/false telemetry

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    rm requirements.txt

COPY ./src/server.py .
COPY ./src/config.py .

# SQLite database can be stored in a volume
VOLUME /app/data

RUN mkdir -p /app/data /app/tmp && chown -R 1001:1001 /app/data /app/tmp
ENV TELEMETRY_DB=/app/data/telemetry.db
ENV TMPDIR=/app/tmp

USER 1001:1001

EXPOSE 8080

CMD ["gunicorn", "server:app", "-c", "/app/config.py"]
