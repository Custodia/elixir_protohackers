# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20221004-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.14.2-erlang-25.1.2-debian-bullseye-20221004-slim
#
ARG ELIXIR_VERSION=1.15.7
ARG OTP_VERSION=26.1.2
ARG DEBIAN_VERSION=bullseye-20231009-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ARG APPLICATION="price_server"

# Set env variables
ENV MIX_ENV="prod"

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install Hex and rebar3
RUN mix do local.hex --force, local.rebar --force

# Copy configuration from this app and all children
COPY config config

# Copy mix.exs and mix.lock from all children applications
COPY mix.exs ./
COPY apps/${APPLICATION}/mix.exs apps/${APPLICATION}/mix.exs
# COPY apps/${APPLICATION}/mix.lock apps/${APPLICATION}/mix.lock

RUN mix do deps.get --only $MIX_ENV, deps.compile

# Copy lib for all applications and compile
COPY apps/${APPLICATION}/lib apps/${APPLICATION}/lib
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY apps/${APPLICATION}/rel apps/${APPLICATION}/rel
RUN mix release ${APPLICATION}

## Runner image

FROM ${RUNNER_IMAGE}

ENV APPLICATION="price_server"

# Install dependencies
RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

COPY --from=builder /app/_build/prod/rel ./

CMD /app/${APPLICATION}/bin/${APPLICATION} start
