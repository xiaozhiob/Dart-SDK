// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:compiler/src/util/testing.dart';

/*class: Class1a:needsArgs*/
class Class1a<T> {
  /*member: Class1a.:*/
  Class1a();

  /*member: Class1a.==:*/
  bool operator ==(other) {
    if (identical(this, other)) return true;
    return runtimeType == other?.runtimeType;
  }
}

/*class: Class1b:needsArgs*/
class Class1b<T> extends Class1a<T> {
  /*member: Class1b.:*/
  Class1b();
}

// TODO(johnniwinther): Specialize handling of `this.runtimeType` to exclude
// this class.
/*class: Class1c:needsArgs*/
class Class1c<T> implements Class1a<T> {
  /*member: Class1c.:*/
  Class1c();
}

/*class: Class2:*/
class Class2<T> {
  /*member: Class2.:*/
  Class2();
}

/*member: main:*/
main() {
  Class1a<int> cls1a = Class1a<int>();
  Class1a<int> cls1b1 = Class1b<int>();
  Class1a<int> cls1b2 = Class1b<int>();
  Class1c<int> cls1c = Class1c<int>();
  Class2<int> cls2 = Class2<int>();
  makeLive(cls1a == cls1b1);
  makeLive(cls1b1 == cls1b2);
  makeLive(cls1a == cls1c);
  makeLive(cls1a == cls2);
}
