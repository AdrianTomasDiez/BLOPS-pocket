import Foundation

/// Guarda el acceso a la carpeta del juego entre aperturas de la app (fase 4).
///
/// En iOS el flag `.withSecurityScope` es solo de macOS: el bookmark se crea con
/// las opciones por defecto y, al resolverlo, la URL devuelta sigue siendo de
/// ámbito de seguridad, así que hay que envolver su uso en
/// `startAccessingSecurityScopedResource()`.
///
/// Privacidad (reglas.md, regla 4): el bookmark puede contener la ruta elegida
/// por el usuario. Se guarda en `UserDefaults` porque es imprescindible para
/// recordar el acceso, pero **nunca** se registra en logs ni se envía a ningún
/// sitio.
enum GameFolderBookmark {
    private static let key = "gameFolderBookmark"

    /// Crea el bookmark de `url` y lo guarda. Debe llamarse con el acceso de
    /// seguridad ya abierto. Devuelve false si no se pudo crear.
    @discardableResult
    static func save(_ url: URL, defaults: UserDefaults = .standard) -> Bool {
        do {
            let data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: key)
            return true
        } catch {
            return false
        }
    }

    /// Devuelve la carpeta guardada, o nil si no hay ninguna o ya no se puede
    /// resolver (por ejemplo, si el usuario la borró de Archivos).
    static func restore(defaults: UserDefaults = .standard) -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                // El bookmark antiguo ya no sirve: lo reescribimos si podemos.
                _ = save(url, defaults: defaults)
            }
            return url
        } catch {
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    /// Olvida la carpeta guardada.
    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func hasSavedFolder(defaults: UserDefaults = .standard) -> Bool {
        defaults.data(forKey: key) != nil
    }
}
