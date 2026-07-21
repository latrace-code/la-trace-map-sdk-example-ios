import Foundation
import LaTraceMapSDK

// LE SEUL FICHIER A ADAPTER CHEZ VOUS.
//
// Le SDK ne stocke rien : vous lui POUSSEZ vos lieux au format `Poi`. Ce fichier
// montre le seul point de contact entre votre modele et le sien. Remplacez
// `SampleRecord` par le type que renvoie votre API et reecrivez les deux tables.
//
// Trois axes independants :
//   - category : categorie de marque grossiere -> COULEUR du marqueur (Config.poiColors)
//   - poiType  : type fin de la taxonomie La Trace -> GLYPHE du marqueur
//   - facets   : filtres riches transverses (terrasse, budget, labels...)

/// Un enregistrement tel que le renvoie « votre » API. Ici il vient du fichier
/// `Resources/sample-pois.json` ; chez vous, de votre backend.
struct SampleRecord: Decodable {
    let id: String
    let title: String
    let kind: String
    let lat: Double
    let lng: Double
    let address: String?
    let city: String?
    let postalCode: String?
    let country: String?
    let price: String?
    let url: String?
    let tags: [String]?
}

extension SampleRecord {

    /// Votre type metier -> categorie de marque (cle de `Config.poiColors`).
    private static let categoryByKind: [String: String] = [
        "restaurant": "restaurant",
        "cafe": "cafe",
        "hotel": "lodging",
        "museum": "culture",
        "park": "nature",
        "bikeshop": "bike",
    ]

    /// Votre type metier -> `PoiType` La Trace (pilote le glyphe). Quelques valeurs
    /// possibles : Restaurant, Cafe, Bar, Bakery, Hotel, BnB, Camping, Museum,
    /// GardenPark, Viewpoint, BikeShop, Market, ProducerShop.
    private static let poiTypeByKind: [String: String] = [
        "restaurant": "Restaurant",
        "cafe": "Cafe",
        "hotel": "Hotel",
        "museum": "Museum",
        "park": "GardenPark",
        "bikeshop": "BikeShop",
    ]

    func asLaTracePoi() -> Poi {
        Poi(
            id: id,
            coords: [lng, lat],
            category: Self.categoryByKind[kind] ?? "restaurant",
            // `LocalizedString` n'est pas un litteral de chaine : `.plain(...)` pour
            // un nom unique, `.localized([.fr: "...", .en: "..."])` pour un nom
            // traduit que `setLocale(_:)` re-resoudra.
            name: .plain(title),
            poiType: Self.poiTypeByKind[kind],
            address: address,
            city: city,
            postalCode: postalCode,
            country: country,
            priceRange: price.flatMap(PriceLevel.init(rawValue:)).map(PriceRange.level),
            externalUrl: url,
            facets: tags.map { ["tags": $0] }
        )
    }

    static func loadBundled() -> [SampleRecord] {
        guard
            let url = Bundle.main.url(forResource: "sample-pois", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let records = try? JSONDecoder().decode([SampleRecord].self, from: data)
        else {
            return []
        }
        return records
    }
}
