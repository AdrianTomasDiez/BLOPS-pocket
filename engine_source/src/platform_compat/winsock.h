#pragma once

#if defined(__APPLE__)

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <poll.h>
#include <ios/win_types_compat.h>

typedef int SOCKET;
#define INVALID_SOCKET  (-1)
#define SOCKET_ERROR    (-1)

#define FD_SETSIZE      64

typedef struct fd_set_win {
    u_int   fd_count;
    SOCKET  fd_array[FD_SETSIZE];
} fd_set;

static inline int __WSAFDIsSet(SOCKET fd, fd_set *set) {
    if (!set) return 0;
    for (u_int i = 0; i < set->fd_count; i++) {
        if (set->fd_array[i] == fd) return 1;
    }
    return 0;
}

static inline int win_select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout) {
    (void)nfds;
    (void)writefds;
    (void)exceptfds;
    struct pollfd pfd;
    pfd.fd = (readfds && readfds->fd_count > 0) ? readfds->fd_array[0] : -1;
    pfd.events = POLLIN;
    pfd.revents = 0;
    int timeout_ms = timeout ? (timeout->tv_sec * 1000 + timeout->tv_usec / 1000) : -1;
    if (pfd.fd < 0) return 0;
    return poll(&pfd, 1, timeout_ms);
}
#define select win_select

#define S_un
#define S_addr s_addr

typedef struct WSAData {
    WORD wVersion;
    WORD wHighVersion;
    char szDescription[257];
    char szSystemStatus[129];
    unsigned short iMaxSockets;
    unsigned short iMaxUdpDg;
    char *lpVendorInfo;
} WSADATA, *LPWSADATA;

static inline int WSAStartup(WORD wVersionRequired, LPWSADATA lpWSAData) {
    (void)wVersionRequired;
    if (lpWSAData) memset(lpWSAData, 0, sizeof(*lpWSAData));
    return 0;
}

static inline int WSACleanup(void) {
    return 0;
}

static inline int closesocket(SOCKET s) {
    return close(s);
}

static inline int WSAGetLastError(void) {
    return errno;
}

#endif
