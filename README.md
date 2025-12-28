# app-password-store-client-git2

A Dart package that provides libgit2 bindings using Dart Hooks.

It is used internally by [app-password-store-client](https://github.com/okadan/app-password-store-client) and not currently published to pub.dev.

## Bindings Generation

This package uses `ffigen` to generate Dart bindings for libgit2. We use Docker to ensure consistent output across different environments.

How to generate bindings:

```sh
$ docker build . -t git2 && docker run -v `pwd`:/workdir git2
```
