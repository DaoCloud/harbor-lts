ARG GOLANG
FROM ${GOLANG}

ARG SWAGGER_VERSION
# Releases this old ship no arm64 binary; build the same version from source there.
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      curl -fsSL -o /usr/bin/swagger https://github.com/go-swagger/go-swagger/releases/download/$SWAGGER_VERSION/swagger_linux_amd64 && chmod +x /usr/bin/swagger; \
    else \
      GOBIN=/usr/bin go install github.com/go-swagger/go-swagger/cmd/swagger@$SWAGGER_VERSION; \
    fi

ENTRYPOINT ["/usr/bin/swagger"]
CMD ["--help"]
