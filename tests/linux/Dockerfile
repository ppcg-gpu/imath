# Build IMath and run tests with GCC on Linux.
#
# Usage (from the imath root):
#
#   docker run --rm -it "$(docker build -f tests/linux/Dockerfile -q .)"
#
FROM alpine:latest AS base

RUN apk add --no-cache bash build-base gcc gmp-dev cmake python3

FROM base AS test
COPY . /imath
WORKDIR /imath
CMD mkdir -p build && cd build && \
    cmake .. && \
    cmake --build . && \
    ctest --output-on-failure
