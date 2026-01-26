# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /workspace

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/ cmd/
COPY pkg/ pkg/

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o flower-addon-manager ./cmd/manager

# Runtime stage
FROM alpine:3.19

WORKDIR /

# Install CA certificates for TLS
RUN apk --no-cache add ca-certificates

# Copy the binary
COPY --from=builder /workspace/flower-addon-manager .

# Run as non-root user
RUN adduser -D -u 1000 appuser
USER appuser

ENTRYPOINT ["/flower-addon-manager"]
