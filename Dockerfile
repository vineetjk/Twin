# Twin web app (Next.js UI + API), built and run by docker-compose.yml.
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

FROM node:22-alpine AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1 NEXT_OUTPUT=standalone
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:22-alpine AS run
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    TWIN_DATA_DIR=/data \
    TWIN_USER=app
# Same uid as the backend image, so both containers can write the shared SQLite database.
# The entrypoint starts as root only to make /data writable (a Render disk is mounted root-owned).
RUN apk add --no-cache setpriv && adduser -S -u 10001 app && mkdir -p /data && chown app /data
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
COPY --from=build /app/content ./content
COPY --chmod=0755 infra/docker/entrypoint.sh /usr/local/bin/twin-entrypoint
EXPOSE 3000
ENTRYPOINT ["twin-entrypoint"]
CMD ["node", "server.js"]
