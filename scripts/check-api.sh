#!/usr/bin/env bash
# Starts the Spring Boot API, runs the Postman collection against it, then stops it.
# Live check that the running code honours the contract.  Usage: ./scripts/check-api.sh
set -u
cd "$(dirname "$0")/.." || exit 1
PORT="${PORT:-8080}"

echo "Building..."
./mvnw -q -B -DskipTests package || exit 1

echo "Starting the API on :$PORT"
java -jar target/appointments-api-*.jar --server.port="$PORT" > target/api.log 2>&1 &
API_PID=$!
trap 'kill $API_PID 2>/dev/null' EXIT

for _ in $(seq 1 40); do curl -sf "http://localhost:$PORT/health" >/dev/null && break; sleep 1; done
curl -sf "http://localhost:$PORT/health" >/dev/null || { echo "API did not start, see target/api.log"; exit 1; }

echo "Running the Postman collection against the live API"
postman collection run "postman/collections/Appointments API" --env-var "baseUrl=http://localhost:$PORT"
