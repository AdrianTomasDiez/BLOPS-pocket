#pragma once
#include <sys/stat.h>
#include <unistd.h>

#ifndef _mkdir
#define _mkdir(p) mkdir((p), 0755)
#endif

#ifndef _getcwd
#define _getcwd(b, s) getcwd((b), (s))
#endif
