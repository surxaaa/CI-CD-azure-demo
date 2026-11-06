# Runtime-only image. The pipeline builds and tests target/app.jar with Maven,
# so the image contains exactly the artifact that passed the tests.
# Build locally with: mvn package && docker build -t gradecalc .
FROM eclipse-temurin:17-jre

WORKDIR /app
COPY target/app.jar app.jar

# Commit SHA baked in at build time; shown on the page and at /api/info.
ARG APP_COMMIT=local
ENV APP_COMMIT=${APP_COMMIT}

# Numeric UID so Kubernetes runAsNonRoot can verify it.
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
