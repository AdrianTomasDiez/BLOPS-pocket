#pragma once
#include <stdint.h>
#include <string.h>

#pragma pack(push, 1)

typedef struct _XINPUT_GAMEPAD {
    uint16_t wButtons;
    uint8_t  bLeftTrigger;
    uint8_t  bRightTrigger;
    int16_t  sThumbLX;
    int16_t  sThumbLY;
    int16_t  sThumbRX;
    int16_t  sThumbRY;
} XINPUT_GAMEPAD, *PXINPUT_GAMEPAD;

typedef struct _XINPUT_STATE {
    uint32_t        dwPacketNumber;
    XINPUT_GAMEPAD  Gamepad;
} XINPUT_STATE, *PXINPUT_STATE;

typedef struct _XINPUT_VIBRATION {
    uint16_t wLeftMotorSpeed;
    uint16_t wRightMotorSpeed;
} XINPUT_VIBRATION, *PXINPUT_VIBRATION;

typedef struct _XINPUT_CAPABILITIES {
    uint8_t             Type;
    uint8_t             SubType;
    uint16_t            Flags;
    XINPUT_GAMEPAD      Gamepad;
    XINPUT_VIBRATION    Vibration;
} XINPUT_CAPABILITIES, *PXINPUT_CAPABILITIES;

#pragma pack(pop)

// Button masks
#define XINPUT_GAMEPAD_DPAD_UP          0x0001
#define XINPUT_GAMEPAD_DPAD_DOWN        0x0002
#define XINPUT_GAMEPAD_DPAD_LEFT        0x0004
#define XINPUT_GAMEPAD_DPAD_RIGHT       0x0008
#define XINPUT_GAMEPAD_START            0x0010
#define XINPUT_GAMEPAD_BACK             0x0020
#define XINPUT_GAMEPAD_LEFT_THUMB       0x0040
#define XINPUT_GAMEPAD_RIGHT_THUMB      0x0080
#define XINPUT_GAMEPAD_LEFT_SHOULDER    0x0100
#define XINPUT_GAMEPAD_RIGHT_SHOULDER   0x0200
#define XINPUT_GAMEPAD_A                0x1000
#define XINPUT_GAMEPAD_B                0x2000
#define XINPUT_GAMEPAD_X                0x4000
#define XINPUT_GAMEPAD_Y                0x8000

#ifndef ERROR_DEVICE_NOT_CONNECTED
#define ERROR_DEVICE_NOT_CONNECTED      1167L
#endif

#ifndef ERROR_SUCCESS
#define ERROR_SUCCESS                   0L
#endif

#ifdef __cplusplus
extern "C" {
#endif

static inline uint32_t XInputGetState(uint32_t dwUserIndex, _XINPUT_STATE *pState) {
    if (pState) {
        memset(pState, 0, sizeof(*pState));
    }
    return ERROR_DEVICE_NOT_CONNECTED;
}

static inline uint32_t XInputSetState(uint32_t dwUserIndex, _XINPUT_VIBRATION *pVibration) {
    return ERROR_DEVICE_NOT_CONNECTED;
}

static inline uint32_t XInputGetCapabilities(uint32_t dwUserIndex, uint32_t dwFlags, _XINPUT_CAPABILITIES *pCapabilities) {
    if (pCapabilities) {
        memset(pCapabilities, 0, sizeof(*pCapabilities));
    }
    return ERROR_DEVICE_NOT_CONNECTED;
}

#ifdef __cplusplus
}
#endif
