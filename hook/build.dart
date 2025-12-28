import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';
import 'package:path/path.dart' as path;

const mbedtlsVersion = '3.6.5';
const libgit2Version = '1.9.2';

Future<void> _downloadAndExtract(String url, String dest) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) {
    throw 'Download failed: url=$url';
  }

  late final Archive archive;
  if (url.endsWith('.tar.gz')) {
    archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(res.bodyBytes));
  } else if (url.endsWith('.tar.bz2')) {
    archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(res.bodyBytes));
  } else {
    throw 'Unsupported extension: $url';
  }

  for (final file in archive) {
    if (file.isFile) {
      final data = file.content as List<int>;
      File(path.join(dest, file.name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    } else {
      Directory(path.join(dest, file.name))
        .createSync(recursive: true);
    }
  }
}

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    // NOTE: this package currently only supports Android and iOS.
    if (input.config.code.targetOS != .android && input.config.code.targetOS != .iOS) return;

    final logger = Logger('')
      ..level = Level.ALL
      ..onRecord.listen((record) => print(record.message));

    final defines = <String, String>{
      'CMAKE_BUILD_TYPE': 'Release',
      'CMAKE_INSTALL_PREFIX': input.outputDirectory.resolve('libgit2/install').toFilePath(),
      'BUILD_CLI': 'OFF',
      'BUILD_TESTS': 'OFF',
    };

    if (input.config.code.targetOS == .android) {
      if (!Directory(input.packageRoot.resolve('.dart_tool/git2/mbedtls-$mbedtlsVersion').toFilePath()).existsSync()) {
        logger.log(Level.INFO, 'Downloading mbedtls $mbedtlsVersion...');
        await _downloadAndExtract(
          'https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-$mbedtlsVersion/mbedtls-$mbedtlsVersion.tar.bz2',
          input.packageRoot.resolve('.dart_tool/git2').toFilePath(),
        );
      }

      await CMakeBuilder.create(
        name: 'mbedtls',
        sourceDir: input.packageRoot.resolve('.dart_tool/git2/mbedtls-$mbedtlsVersion'),
        outDir: input.outputDirectory.resolve('mbedtls/out'),
        targets: ['install'],
        defines: {
          'CMAKE_BUILD_TYPE': 'Release',
          'CMAKE_INSTALL_PREFIX': input.outputDirectory.resolve('mbedtls/install').toFilePath(),
          'ENABLE_PROGRAMS': 'OFF',
          'ENABLE_TESTING': 'OFF',
        },
        logger: logger,
      ).run(input: input, output: output, logger: logger);
      defines.addAll({
        'USE_HTTPS': 'mbedTLS',
        'MBEDTLS_INCLUDE_DIR': input.outputDirectory.resolve('mbedtls/install/include').toFilePath(),
        'MBEDTLS_LIBRARY': input.outputDirectory.resolve('mbedtls/install/lib/libmbedtls.a').toFilePath(),
        'MBEDX509_LIBRARY': input.outputDirectory.resolve('mbedtls/install/lib/libmbedx509.a').toFilePath(),
        'MBEDCRYPTO_LIBRARY': input.outputDirectory.resolve('mbedtls/install/lib/libmbedcrypto.a').toFilePath(),
      });
    } else if (input.config.code.targetOS == .iOS) {
      defines.addAll({
        'USE_HTTPS': 'SecureTransport',
      });
    }

    if (!Directory(input.packageRoot.resolve('.dart_tool/git2/libgit2-$libgit2Version').toFilePath()).existsSync()) {
      logger.log(Level.INFO, 'Downloading libgit2 $libgit2Version...');
      await _downloadAndExtract(
        'https://github.com/libgit2/libgit2/archive/refs/tags/v$libgit2Version.tar.gz',
        input.packageRoot.resolve('.dart_tool/git2').toFilePath(),
      );
    }

    await CMakeBuilder.create(
      name: 'git2',
      sourceDir: input.packageRoot.resolve('.dart_tool/git2/libgit2-$libgit2Version'),
      outDir: input.outputDirectory.resolve('libgit2/out'),
      targets: ['install'],
      defines: defines,
      logger: logger,
    ).run(input: input, output: output, logger: logger);

    await output.findAndAddCodeAssets(
      input,
      outDir: input.outputDirectory.resolve('libgit2/install'),
      names: {r'(lib)?git2(\.\d+)*\.(dll|so|dylib)': 'git2.dart'},
      regExp: true,
      logger: logger,
    );
  });
}
