FROM alpine:3.22 AS builder

RUN apk add zig

WORKDIR /app

COPY src src
COPY build.zig build.zig.zon .

RUN zig build --release=fast


FROM alpine:3.22

WORKDIR /app

COPY --from=builder /app/zig-out/bin/dyn_porkbun .

CMD ["./dyn_porkbun"]
