# ─── Stage 1: Build ───────────────────────
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /workspace

COPY pom.xml .
COPY src src

RUN apt-get update && apt-get install -y maven && \
    mvn package -DskipTests -q

# ─── Stage 2: Runtime ─────────────────────
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY --from=build /workspace/target/*.jar app.jar

RUN mkdir -p /app/logs

EXPOSE 8081

ENTRYPOINT ["java", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-Xms256m", "-Xmx512m", \
  "-jar", "app.jar"]
