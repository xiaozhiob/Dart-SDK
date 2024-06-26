// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "platform/globals.h"
#if defined(DART_HOST_OS_LINUX)

#include <sys/utsname.h>

#include "platform/utils.h"
#include "platform/utils_linux.h"

namespace dart {

char* Utils::StrNDup(const char* s, intptr_t n) {
  return strndup(s, n);
}

char* Utils::StrDup(const char* s) {
  return strdup(s);
}

intptr_t Utils::StrNLen(const char* s, intptr_t n) {
  return strnlen(s, n);
}

int Utils::SNPrint(char* str, size_t size, const char* format, ...) {
  va_list args;
  va_start(args, format);
  int retval = VSNPrint(str, size, format, args);
  va_end(args);
  return retval;
}

int Utils::VSNPrint(char* str, size_t size, const char* format, va_list args) {
  int retval = vsnprintf(str, size, format, args);
  if (retval < 0) {
    FATAL("Fatal error in Utils::VSNPrint with format '%s'", format);
  }
  return retval;
}

int Utils::Close(int fildes) {
  return close(fildes);
}

size_t Utils::Read(int filedes, void* buf, size_t nbyte) {
  return read(filedes, buf, nbyte);
}

int Utils::Unlink(const char* path) {
  return unlink(path);
}

bool Utils::IsWindowsSubsystemForLinux() {
  struct utsname info;
  if (uname(&info) != 0) {
    return false;  // Not sure.
  }

  // If info.release contains either Microsoft or microsoft then we are
  // most likely running under WSL.
  return strstr(info.release, "icrosoft") != nullptr;
}

}  // namespace dart

#endif  // defined(DART_HOST_OS_LINUX)
