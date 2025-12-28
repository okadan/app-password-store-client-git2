FROM dart:stable

ARG LIBGIT2_VERSION=1.9.2

WORKDIR /workdir

RUN apt-get update && apt-get install -y --no-install-recommends libclang-dev

RUN mkdir -p /opt/libgit2 && \
  curl -L https://github.com/libgit2/libgit2/archive/refs/tags/v${LIBGIT2_VERSION}.tar.gz | \
  tar -zxC /opt/libgit2 --strip-components=1

RUN dart pub global activate ffigen

COPY pubspec.yaml ./

CMD ["dart", "pub", "global", "run", "ffigen"]
