    # Use the official Golang image matching your go.mod version (1.24.2)
    # Alpine base image is smaller
    FROM golang:1.24.2-alpine as builder

    # Set working directory
    WORKDIR /app

    # Copy go module files and download dependencies
    # This leverages Docker layer caching
    COPY go.mod go.sum ./
    RUN go mod download

    # Copy the rest of the source code
    COPY . .

    # Build the Go application binary
    # -ldflags="-w -s" strips debug info, reduces size
    # CGO_ENABLED=0 ensures static binary without C dependencies (good for alpine)
    # Output path is /app/server inside the builder stage
    RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o /app/server ./cmd/server

    # --- Final runtime image ---
    # Use a minimal non-root image for security
    FROM gcr.io/distroless/static-debian11

    # Copy only the compiled binary from the builder stage
    COPY --from=builder /app/server /server

    # Expose the port the app runs on (must match PORT env var)
    # Cloud Run default is 8080
    EXPOSE 8080

    # Command to run the executable
    # The server binary uses the PORT env var provided by Cloud Run
    ENTRYPOINT ["/server"]