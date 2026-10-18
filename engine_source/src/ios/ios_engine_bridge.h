#pragma once

#ifdef __cplusplus
extern "C" {
#endif

void bo1_ios_update_progress(const char *zone, const char *asset, int current, int total, const char *stage);
void bo1_ios_set_error(const char *error);
void bo1_ios_set_game_running(void);

void bo1_ios_get_progress_info(
    char *outZone, int maxZoneLen,
    char *outAsset, int maxAssetLen,
    int *outCurrent, int *outTotal,
    int *outPercent,
    char *outStage, int maxStageLen,
    char *outError, int maxErrorLen,
    int *outHasError,
    int *outIsComplete
);

#ifdef __cplusplus
}
#endif
