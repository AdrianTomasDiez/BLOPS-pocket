// Archivos base de main/ que la instalación de PC trae y el Play de iOS no: el motor los exige en la
// carpeta del juego. Generado desde engine_source/data/main/playlists_sp.info (mismo contenido que la
// copia de escritorio). Lo escribe GameFolderLocator/NativeEngineView si falta; no sobrescribe.
enum BaseGameData {
    /// Marcador leído por FS_IsBasePathValid (com_files.cpp). Su contenido solo tiene que ser legible y no vacío.
    static let fileSysCheckContents = "// Marcador de instalación de BLOPS pocket (FS_IsBasePathValid).\n"

    static let playlistsSpContents = #"""
// playlists_sp.info - offline stand-in for the retail online WAD entry of the same name.
// Retail Black Ops (SP/zombies exe) downloads the Demonware publisher file online_tu14_sp_<language>.wad and parses
// its playlists_sp.info with Playlist_ParsePlaylists; a `settings` block's `setdvar` lines set dvars.
// The real file is not on disk anywhere in the install. The values below are MEASURED: the retail session's dvar
// pool (retail research extracted/exe/dvars-live.json, all ten flags 0x4000 = created by this path).
// scr_zm_extra_perk_*: read by maps/_zombiemode_ffotd.gsc; the Mule Kick machine stays on a map when its own dvar
// or scr_zm_extra_perk_all is non-zero (zombie_moon always has it), otherwise the script removes it.
settings
setdvar scr_zm_extra_perk_all 1
setdvar scr_zm_extra_perk_theater 0
setdvar scr_zm_extra_perk_pentagon 0
setdvar scr_zm_extra_perk_cosmodrome 0
setdvar scr_zm_extra_perk_coast 0
setdvar scr_zm_extra_perk_temple 0
setdvar scr_zm_extra_perk_cod5_prototype 0
setdvar scr_zm_extra_perk_cod5_asylum 0
setdvar scr_zm_extra_perk_cod5_sumpf 0
setdvar scr_zm_extra_perk_cod5_factory 0
"""#

    /// Escribe en <gameFolder>/main/ los archivos que falten. Devuelve los nombres creados.
    @discardableResult
    static func ensureInstalled(in gameFolder: URL) throws -> [String] {
        let fileManager = FileManager.default
        let mainFolder = gameFolder.appendingPathComponent("main", isDirectory: true)
        try fileManager.createDirectory(at: mainFolder, withIntermediateDirectories: true)

        let files: [(name: String, contents: String)] = [
            ("fileSysCheck.cfg", fileSysCheckContents),
            ("playlists_sp.info", playlistsSpContents),
        ]
        var created: [String] = []
        for file in files {
            let target = mainFolder.appendingPathComponent(file.name)
            if fileManager.fileExists(atPath: target.path) { continue }
            try file.contents.write(to: target, atomically: true, encoding: .utf8)
            created.append(file.name)
        }
        return created
    }
}
