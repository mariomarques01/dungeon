FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip -o /tmp/godot.zip && unzip /tmp/godot.zip -d /usr/local/bin && mv /usr/local/bin/Godot_v4.4.1-stable_linux.x86_64 /usr/local/bin/godot && rm /tmp/godot.zip
WORKDIR /app
COPY godot/ ./godot/
COPY server/ ./server/
EXPOSE 9080
CMD ["godot", "--headless", "--path", "godot", "--script", "/app/server/rooms.gd"]
