import UIKit
import Combine
import LaTraceMapSDK

// Exemple d'integration du SDK carto La Trace en natif iOS.
//
// 1. On instancie la carte pilotee (`LaTraceExploreMapView`).
// 2. On lui POUSSE nos lieux au format `Poi` (voir ApiToPoi.swift). Zero stockage
//    cote La Trace : la carte n'affiche que ce que l'hote lui envoie.
// 3. On ecoute les evenements du pont (tap sur un marqueur, deplacement de la carte).
// 4. (Optionnel) `LaTraceGeocoder` alimente notre propre barre de recherche.
// 5. (Optionnel) `laTraceStaticMapRequest` fournit la vignette de la fiche.
//
// Tout le chrome visible ici (barre de recherche, bouton de zone, fiche) est NATIF :
// la carte est chargee en mode nu et ne rend qu'elle-meme.
final class MapViewController: UIViewController {

    private let records = SampleRecord.loadBundled()
    private lazy var pois: [Poi] = records.map { $0.asLaTracePoi() }

    private lazy var mapView = LaTraceExploreMapView(options: LaTraceExploreOptions(
        apiKey: Config.apiKey,
        configId: Config.configId,
        exploreBaseUrl: Config.exploreBaseURL,
        initialConfig: ConfigOverride(
            poiColors: Config.poiColors,
            // Logo custom du marqueur (en plus de la couleur), voir Config.poiIcons.
            poiIcons: Config.poiIcons,
            // La fiche est chez nous : l'embed ne doit ouvrir aucun panneau ni aucune
            // preview, sinon sa propre surface se glisse sous la notre et le marqueur
            // tape reste emphase indefiniment.
            poiDetailMode: .hostHandled
        ),
        locale: .fr
    ))

    private lazy var geocoder = LaTraceGeocoder(
        apiKey: Config.apiKey,
        apiBaseUrl: Config.apiBaseURL,
        countries: Config.geocodeCountries
    )

    private let searchBar = UISearchBar()
    private let searchAreaButton = UIButton(type: .system)
    private let card = PoiCardView()

    private var cancellables = Set<AnyCancellable>()
    private var lastViewport: Viewport?
    private var queriedBBox: BBox?
    private var thumbnailTask: URLSessionDataTask?
    private var searchTask: Task<Void, Never>?

    /// Ce que la carte porte aujourd'hui : corpus pousse et fiche ouverte. La carte
    /// ne les rend pas a l'hote, et un redemarrage du process web les efface, donc
    /// c'est a l'hote de les tenir pour pouvoir les rejouer (voir `onReloaded`).
    private var pushedPois: [Poi] = []
    private var selectedPoiId: String?

    // MARK: - Cycle de vie

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        guard !Config.isPlaceholder else {
            showConfigurationNotice()
            return
        }

        layout()
        wireEvents()

        pushCorpus(pois)
        // Sans padding, l'embed applique le sien (40 px de chaque cote en mode nu).
        // Un `Padding` partiel met les cotes omis a zero : pour degager une bottom
        // sheet sans coller les marqueurs aux autres bords, renseigner les 4 cotes.
        if let bbox = Self.boundingBox(of: pois) {
            mapView.map.fitBounds(bbox)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !Config.isPlaceholder else { return }
        mapView.setVisible(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !Config.isPlaceholder else { return }
        mapView.setVisible(false)
    }

    deinit {
        searchTask?.cancel()
        thumbnailTask?.cancel()
        guard !Config.isPlaceholder else { return }
        // Envoie les compteurs d'usage en attente pendant que la web view vit encore.
        mapView.map.destroy()
    }

    // MARK: - Evenements du pont

    private func wireEvents() {
        // Un tap sur un marqueur n'ouvre rien : il signale, l'hote decide.
        mapView.map.onPinClick(in: &cancellables) { [weak self] poi in
            self?.showCard(for: poi.id)
        }

        // Seul signal de mouvement de la carte (il n'y a pas d'evenement `idle`
        // distinct). En mode nu, le bouton « rechercher dans cette zone » de l'embed
        // est masque et n'emet donc jamais `searchArea` : c'est ce viewport qui nous
        // sert de declencheur.
        mapView.map.onViewportChange(in: &cancellables) { [weak self] viewport in
            self?.handleViewport(viewport)
        }

        // Ce que l'embed a refuse apres un push : sans ca, un corpus perd des entrees
        // sans laisser de trace cote hote.
        mapView.map.onPoisRejected(in: &cancellables) { rejected in
            NSLog("[exemple] POIs refuses par la carte : %@", String(describing: rejected))
        }

        mapView.map.observeEvents(in: &cancellables) { event in
            if case .error(let code, let message) = event {
                NSLog("[exemple] erreur carte %@ : %@", code, message)
            }
        }

        // Apres un redemarrage du process web (iOS recycle les web views), tout ce que
        // l'hote avait pousse est perdu : le corpus, le cadrage et la selection. Le
        // SDK ne les rejoue pas a notre place, on rejoue les trois.
        mapView.onReloaded = { [weak self] in
            guard let self else { return }
            self.pushCorpus(self.pushedPois)
            if let viewport = self.lastViewport {
                // Restituer le cadrage par `fitBounds(viewport.bbox)` reappliquerait
                // le padding de l'embed et dezoomerait a chaque redemarrage.
                self.mapView.map.flyTo(CameraTarget(center: viewport.center, zoom: viewport.zoom))
            } else if let bbox = Self.boundingBox(of: self.pushedPois) {
                self.mapView.map.fitBounds(bbox)
            }
            if let selectedPoiId = self.selectedPoiId {
                self.mapView.map.highlightPin(selectedPoiId)
            }
        }
    }

    // MARK: - Corpus

    private func pushCorpus(_ pois: [Poi]) {
        pushedPois = pois
        // `setPois` REMPLACE tout le corpus et rend ce qu'il a refuse cote client
        // (id vide, coordonnees non finies).
        let result = mapView.map.setPois(pois)
        if !result.rejected.isEmpty {
            NSLog("[exemple] POIs invalides, non envoyes : %@", String(describing: result.rejected))
        }
    }

    private func handleViewport(_ viewport: Viewport) {
        lastViewport = viewport
        guard let queried = queriedBBox else {
            queriedBBox = viewport.bbox
            return
        }
        setSearchAreaButtonVisible(!Self.bbox(queried, contains: viewport.center))
    }

    @objc private func searchThisArea() {
        guard let bbox = lastViewport?.bbox else { return }
        queriedBBox = bbox
        setSearchAreaButtonVisible(false)
        // Chez vous : interroger votre API sur cette bbox, puis re-pousser le resultat.
        pushCorpus(pois.filter { Self.bbox(bbox, contains: $0.coords) })
    }

    // MARK: - Fiche de l'hote

    private func showCard(for poiId: String) {
        guard let record = records.first(where: { $0.id == poiId }) else { return }
        selectedPoiId = poiId
        mapView.map.highlightPin(poiId)
        card.show(name: record.title, address: record.address)
        loadThumbnail(for: record.asLaTracePoi())
    }

    /// Vignette de la fiche : le vrai endpoint `/static-map` (un PNG rendu par le
    /// serveur), servi par la passerelle API et non par l'hote Explore. En natif
    /// l'authentification passe par l'en-tete `X-LaTrace-Key`, donc aucune URL
    /// signee et aucun secret dans l'app (voir le README).
    private func loadThumbnail(for poi: Poi) {
        thumbnailTask?.cancel()
        guard let request = laTraceStaticMapRequest(
            configId: Config.configId,
            apiKey: Config.apiKey,
            apiBaseUrl: Config.apiBaseURL,
            center: poi.coords,
            zoom: 15,
            size: CGSize(width: 96, height: 72),
            pois: [poi],
            // Memes tables que la carte : le pin de la vignette est celui de la carte.
            // Un logo en data URI est ignore ici (https uniquement, cf. Config.poiIcons) :
            // la vignette retombe alors sur le glyphe La Trace, la carte garde le logo.
            poiColors: Config.poiColors,
            poiIcons: Config.poiIcons
        ) else {
            return
        }
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.card.thumbnail.image = image }
        }
        thumbnailTask = task
        task.resume()
    }

    // MARK: - Recherche de lieu (geocodage)

    private func flyToPlace(_ query: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                // `autocomplete(_:)` est la variante a la frappe (8 resultats max).
                let results = try await self.geocoder.geocode(query, locale: .fr)
                guard let first = results.first else { return }
                await MainActor.run {
                    self.mapView.map.flyTo(CameraTarget(center: first.coords, zoom: 13))
                }
            } catch {
                NSLog("[exemple] geocodage KO : %@", String(describing: error))
            }
        }
    }

    // MARK: - Geometrie

    private static func boundingBox(of pois: [Poi]) -> BBox? {
        let coords = pois.map(\.coords).filter { $0.count == 2 }
        let lngs = coords.map { $0[0] }
        let lats = coords.map { $0[1] }
        guard
            let west = lngs.min(), let east = lngs.max(),
            let south = lats.min(), let north = lats.max()
        else {
            return nil
        }
        return [west, south, east, north]
    }

    /// `BBox` vaut `[ouest, sud, est, nord]` et `LngLat` vaut `[lng, lat]`.
    private static func bbox(_ bbox: BBox, contains coords: LngLat) -> Bool {
        guard bbox.count == 4, coords.count == 2 else { return false }
        return coords[0] >= bbox[0] && coords[0] <= bbox[2]
            && coords[1] >= bbox[1] && coords[1] <= bbox[3]
    }

    // MARK: - Mise en page

    private func layout() {
        searchBar.placeholder = "Rechercher un lieu"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self

        searchAreaButton.setTitle("Rechercher dans cette zone", for: .normal)
        searchAreaButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        searchAreaButton.backgroundColor = .systemBackground
        searchAreaButton.layer.cornerRadius = 16
        searchAreaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        searchAreaButton.isHidden = true
        searchAreaButton.addTarget(self, action: #selector(searchThisArea), for: .touchUpInside)

        card.onClose = { [weak self] in
            self?.card.isHidden = true
            self?.selectedPoiId = nil
            self?.mapView.map.highlightPin(nil)
        }

        for subview in [mapView, searchBar, searchAreaButton, card] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: guide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -8),

            mapView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            searchAreaButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 12),
            searchAreaButton.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),

            card.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
        ])
    }

    private func setSearchAreaButtonVisible(_ visible: Bool) {
        searchAreaButton.isHidden = !visible
    }

    /// Affiche a la place de la carte tant que `Config` porte les valeurs du depot :
    /// celles-ci ne designent aucun deploiement, la web view chargerait une URL qui
    /// n'existe pas et l'ecran resterait vide sans dire pourquoi.
    private func showConfigurationNotice() {
        let label = UILabel()
        label.text = """
            Configuration manquante.

            Renseignez les quatre valeurs de LaTraceExample/Config.swift : cle publiable, \
            configId, hote Explore et passerelle API. La Trace vous les transmet avec vos \
            identifiants de demo (voir le README).
            """
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .callout)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let guide = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
        ])
    }
}

extension MapViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let query = searchBar.text, !query.isEmpty else { return }
        flyToPlace(query)
    }
}
