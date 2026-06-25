FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o aip-server .

FROM alpine:3.19

RUN apk add --no-cache ffmpeg

WORKDIR /app

COPY --from=builder /app/aip-server .
COPY --from=builder /app/.env* ./

RUN mkdir -p uploads

EXPOSE 8005

CMD ["./aip-server"]
