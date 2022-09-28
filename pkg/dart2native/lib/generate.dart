// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

import 'dart2native.dart';

final Directory binDir = File(Platform.resolvedExecutable).parent;
final String executableSuffix = Platform.isWindows ? '.exe' : '';
final String dartaotruntime =
    path.join(binDir.path, 'dartaotruntime$executableSuffix');
final String genKernel =
    path.join(binDir.path, 'snapshots', 'gen_kernel.dart.snapshot');
final String genSnapshot =
    path.join(binDir.path, 'utils', 'gen_snapshot$executableSuffix');
final String productPlatformDill = path.join(
    binDir.parent.path, 'lib', '_internal', 'vm_platform_strong_product.dill');

Future<void> generateNative({
  String kind = 'exe',
  required String sourceFile,
  String? outputFile,
  String? debugFile,
  String? packages,
  required List<String> defines,
  String enableExperiment = '',
  bool enableAsserts = false,
  bool? soundNullSafety,
  bool verbose = false,
  String verbosity = 'all',
  List<String> extraOptions = const [],
}) async {
  final Directory tempDir = Directory.systemTemp.createTempSync();
  try {
    final sourcePath = path.canonicalize(path.normalize(sourceFile));
    if (packages != null) {
      packages = path.canonicalize(path.normalize(packages));
    }
    final Kind outputKind = {
      'aot': Kind.aot,
      'exe': Kind.exe,
    }[kind]!;
    final sourceWithoutDart = sourcePath.replaceFirst(RegExp(r'\.dart$'), '');
    final outputPath = path.canonicalize(path.normalize(outputFile ??
        {
          Kind.aot: '$sourceWithoutDart.aot',
          Kind.exe: '$sourceWithoutDart.exe',
        }[outputKind]!));
    final debugPath =
        debugFile != null ? path.canonicalize(path.normalize(debugFile)) : null;

    if (verbose) {
      print('Compiling $sourcePath to $outputPath using format $kind:');
      print('Generating AOT kernel dill.');
    }

    final String kernelFile = path.join(tempDir.path, 'kernel.dill');
    final kernelResult = await generateAotKernel(Platform.executable, genKernel,
        productPlatformDill, sourcePath, kernelFile, packages, defines,
        enableExperiment: enableExperiment,
        extraGenKernelOptions: [
          '--invocation-modes=compile',
          '--verbosity=$verbosity',
          if (soundNullSafety != null)
            '--${soundNullSafety ? '' : 'no-'}sound-null-safety',
        ]);
    await _forwardOutput(kernelResult);
    if (kernelResult.exitCode != 0) {
      throw 'Generating AOT kernel dill failed!';
    }

    if (verbose) {
      print('Generating AOT snapshot.');
    }

    final String snapshotFile = (outputKind == Kind.aot
        ? outputPath
        : path.join(tempDir.path, 'snapshot.aot'));
    final snapshotResult = await generateAotSnapshot(genSnapshot, kernelFile,
        snapshotFile, debugPath, enableAsserts, extraOptions);

    if (verbose || kernelResult.exitCode != 0) {
      await _forwardOutput(kernelResult);
    }
    if (snapshotResult.exitCode != 0) {
      throw 'Generating AOT snapshot failed!';
    }

    if (outputKind == Kind.exe) {
      if (verbose) {
        print('Generating executable.');
      }
      await writeAppendedExecutable(dartaotruntime, snapshotFile, outputPath);

      if (Platform.isLinux || Platform.isMacOS) {
        if (verbose) {
          print('Marking binary executable.');
        }
        await markExecutable(outputPath);
      }
    }

    print('Generated: $outputPath');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

Future<void> _forwardOutput(ProcessResult result) async {
  if (result.stdout.isNotEmpty) {
    final bool needsNewLine = !result.stdout.endsWith('\n');
    if (result.exitCode == 0) {
      stdout.write(result.stdout);
      if (needsNewLine) stdout.writeln();
      await stdout.flush();
    } else {
      stderr.write(result.stdout);
      if (needsNewLine) stderr.writeln();
    }
  }
  if (result.stderr.isNotEmpty) {
    stderr.write(result.stderr);
    if (!result.stderr.endsWith('\n')) stderr.writeln();
    await stderr.flush();
  }
}
