// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// The library and its part is both technically at language version
// %VERSION_MARKER1%, but one is explicitly set, the other is not. That's an
// error.

part /*error: errors=LanguageVersionMismatchInPart*/ 'part.dart';

/*library: languageVersion=%VERSION_MARKER1%*/

foo() {
  bar();
}
