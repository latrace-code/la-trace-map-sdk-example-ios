import Foundation
import LaTraceMapSDK

// Configuration de l'exemple. Les quatre premieres valeurs vous sont transmises par
// La Trace avec vos identifiants de demo. Ce depot est PUBLIC : il ne contient ni
// cle, ni identifiant de carte, ni hote reel. Les valeurs ci-dessous sont des
// marqueurs qui ne designent aucun deploiement (TLD `.invalid`, reserve par la
// RFC 2606) ; tant qu'elles sont la, l'app affiche un message au lieu d'une carte.
//
// Rien ici n'est un secret : sur iOS, tout ce qui est dans le binaire est lisible
// (voir la section « Cles et secrets » du README). Seule une cle PUBLIABLE a sa place
// dans une app ; le secret de signature des cartes statiques, lui, n'en a aucune.
enum Config {

    /// Marqueur des valeurs non renseignees, reconnu par ``isPlaceholder``.
    private static let toFill = "a-remplacer"

    /// Cle publiable native (`pk_live_*`). Elle doit etre provisionnee avec
    /// `allowedOrigins: ["*"]` : un client natif n'envoie pas d'en-tete `Origin`, et
    /// une cle restreinte a des domaines repond 403 `origin_not_allowed` sur
    /// `/geocode` et `/static-map`.
    static let apiKey = "pk_live_\(toFill)"

    /// Id de votre carte (`ClientMap`) : territoire, theme et compteur de stats.
    /// C'est un UUID chez vous. Le marqueur n'en a volontairement pas la forme :
    /// un faux UUID bien forme resoudrait silencieusement une autre carte.
    static let configId = toFill

    /// Hote qui sert la carte `/explore`. Depend de l'environnement, jamais devine
    /// par le SDK : La Trace vous le communique avec la cle. Tous les deploiements
    /// Explore ne conviennent pas, seuls ceux qui servent le transport natif
    /// (`transport=native`) repondent au pont ; voir le README.
    static let exploreBaseURL = URL(string: "https://explore.\(toFill).invalid")!

    /// Passerelle API (`/geocode`, `/static-map`). Ce n'est PAS l'hote Explore :
    /// celui-ci repond son shell SPA sur n'importe quel chemin.
    static let apiBaseURL = URL(string: "https://api.\(toFill).invalid")!

    /// Allowlist ISO-2 du geocodage. Sans elle, l'index repond loin hors de votre
    /// territoire ("Gent" renvoie un resultat neerlandais).
    static let geocodeCountries = "fr,be"

    /// Vrai tant que les valeurs ci-dessus sont celles du depot. La carte ne peut
    /// alors pas se charger : l'exemple le dit a l'ecran plutot que de rendre un
    /// fond vide sans explication.
    static var isPlaceholder: Bool {
        [apiKey, configId, exploreBaseURL.absoluteString, apiBaseURL.absoluteString]
            .contains { $0.contains(toFill) }
    }

    /// Couleur du marqueur par categorie hote (celle produite par `ApiToPoi`).
    /// Source unique : la carte interactive et la vignette statique lisent cette
    /// meme table, donc le pin d'une fiche est celui de la carte.
    static let poiColors: [String: ConfigOverride.PoiColor] = [
        "restaurant": ConfigOverride.PoiColor(background: "#FFF3B0", text: "#C79A00"),
        "cafe": ConfigOverride.PoiColor(background: "#FBE7D3", text: "#E8720C"),
        "lodging": ConfigOverride.PoiColor(background: "#DDEEF9", text: "#3B9BD6"),
        "culture": ConfigOverride.PoiColor(background: "#E7DCEE", text: "#774192"),
        "nature": ConfigOverride.PoiColor(background: "#DFF2E1", text: "#2F8F46"),
        "bike": ConfigOverride.PoiColor(background: "#FBE0E1", text: "#E5484D"),
    ]
}
