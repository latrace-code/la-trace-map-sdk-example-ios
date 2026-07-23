# Exemple d'integration iOS - SDK carto La Trace

Exemple minimal et compilable du SDK `LaTraceMapSDK` (Swift) : une carte interactive
embarquee (le vrai `/explore` La Trace, pilote depuis Swift), une recherche de lieu
(geocodage) et une vignette de carte statique dans la fiche.

Le SDK est **zero-stockage** : vous poussez vos lieux a la carte, rien n'est stocke
cote La Trace. Et il est **pilote** : la carte ne rend qu'elle-meme (marqueurs, camera,
fond de carte). La bottom sheet, la fiche, la recherche et les filtres restent chez
vous, en natif. Tout le chrome visible dans cet exemple est du UIKit de l'hote.

C'est le pendant iOS de l'exemple web
[`la-trace-map-sdk-example`](https://github.com/latrace-code/la-trace-map-sdk-example).

## Demarrage

```bash
brew install xcodegen          # une fois
xcodegen generate              # ecrit LaTraceExample.xcodeproj
open LaTraceExample.xcodeproj
```

Puis renseignez vos quatre valeurs dans `LaTraceExample/Config.swift` et lancez sur
simulateur. Xcode resout le package `LaTraceMapSDK` tout seul au premier build.
Tant que `Config.swift` porte les valeurs du depot, l'app affiche un message a la
place de la carte : ces valeurs ne designent aucun deploiement.

Pour travailler contre une copie locale du SDK, remplacez dans `project.yml` les
lignes `url:` / `branch:` par `path: ../la-trace-map-sdk-swift`.

### Quelle version du SDK

`project.yml` epingle `from: "1.0.3"`. Le depot du SDK est **public** : SwiftPM le
resout sans authentification, et `from:` prend automatiquement les correctifs
compatibles (1.0.x, 1.x) sans jamais franchir une version majeure.

### Sans XcodeGen

XcodeGen est le chemin recommande ; ce depot ne versionne pas de `.xcodeproj`. A la
main, la procedure exacte est celle-ci - le raccourci « projet vide + glisser les
fichiers » ne compile pas (deux `@main`) :

1. `File > New > Project > iOS > App`. Nom `LaTraceExample`, Interface **Storyboard**,
   Language **Swift**. (L'interface SwiftUI ne genere ni `AppDelegate` ni
   `SceneDelegate` ; cet exemple est en UIKit.)
2. Supprimez du projet genere (« Move to Trash ») `AppDelegate.swift`,
   `SceneDelegate.swift`, `ViewController.swift` et `Main.storyboard`. Les deux
   premiers existent deja dans ce depot, et deux `@main` ne compilent pas.
3. Glissez dans le target les six fichiers de `LaTraceExample/` (`AppDelegate.swift`,
   `SceneDelegate.swift`, `Config.swift`, `ApiToPoi.swift`, `MapViewController.swift`,
   `PoiCardView.swift`) et le dossier `Resources/`, avec « Copy items if needed » et
   « Add to targets » coche.
4. Le storyboard supprime laisse deux references mortes, onglet **Info** du target :
   - `Main storyboard file base name` (`UIMainStoryboardFile`) : supprimer la ligne ;
   - `Application Scene Manifest > Scene Configuration > Application Session Role >
     Item 0 > Storyboard Name` : supprimer la ligne. **Gardez** `Delegate Class Name`
     a `$(PRODUCT_MODULE_NAME).SceneDelegate` : c'est lui qui donne la main a
     `SceneDelegate`, qui installe `MapViewController`.
5. `File > Add Package Dependencies...`, URL
   `https://github.com/latrace-code/la-trace-map-sdk-swift.git`, regle de dependance
   **Up to Next Major Version** `1.0.3`, produit `LaTraceMapSDK`.

## Les quatre valeurs a renseigner

| Valeur | Ce que c'est |
| --- | --- |
| `apiKey` | Cle publiable native. En preprod (integration), La Trace vous fournit une cle `pk_test_*` ; la `pk_live_*` de production arrive a la mise en service. Dans les deux cas, provisionnee avec `allowedOrigins: ["*"]` : un client natif n'envoie pas d'en-tete `Origin`, et une cle restreinte a des domaines repond 403 `origin_not_allowed` sur `/geocode` et `/static-map`. |
| `configId` | Id de votre carte (`ClientMap`) : territoire, theme, compteur de stats. Un UUID. |
| `exploreBaseURL` | Hote qui sert la carte `/explore`. Tous les deploiements Explore ne conviennent pas : le pont exige un front qui sert le **transport natif** (`transport=native`). C'est un fait de deploiement, pas une constante, et c'est pourquoi le SDK ne le devine jamais : La Trace vous donne l'hote qui convient a votre environnement. |
| `apiBaseURL` | Passerelle API, qui sert `/geocode` et `/static-map`. **Pas** l'hote Explore : celui-ci repond son shell SPA sur n'importe quel chemin. |

**Aucune des quatre n'est devinable et aucune n'est dans ce depot** : il est public,
il ne contient donc ni cle, ni id de carte, ni hote reel. Les valeurs livrees sont
des marqueurs (`a-remplacer`, et le TLD reserve `.invalid` pour les deux URL) que
`Config.isPlaceholder` reconnait pour afficher un message au lancement.

Les vraies valeurs vous sont transmises par La Trace avec vos identifiants de demo,
en meme temps que le lien vers le contrat d'API. Pendant l'integration, tout tourne
en preprod ; l'hote de production vous est communique a la mise en service.

## Les 3 briques

1. **Carte embarquee** : `LaTraceExploreMapView(options: LaTraceExploreOptions(...))`,
   puis `map.setPois(mesLieux.map { $0.asLaTracePoi() })` et `map.fitBounds(bbox)`.
   Le tap sur un marqueur, le deplacement de la carte, etc. arrivent par
   `map.onPinClick(in:_:)`, `map.onViewportChange(in:_:)` ou `map.eventsPublisher`.

2. **Geocodage** (votre propre barre de recherche) :
   `LaTraceGeocoder(apiKey:apiBaseUrl:countries:).autocomplete(_:)` a la frappe, ou
   `.geocode(_:)` pour une requete complete, puis `map.flyTo(...)`.

3. **Carte statique** (vignette hors carte, ex. fiche) : `laTraceStaticMapRequest(...)`
   rend une `URLRequest` deja authentifiee, a executer avec `URLSession`.

## Le tableau des fichiers

| Fichier | Role |
| --- | --- |
| `LaTraceExample/ApiToPoi.swift` | **Le seul fichier a adapter chez vous** : mapper un enregistrement de votre API vers le format `Poi` du SDK. |
| `LaTraceExample/Config.swift` | Les quatre valeurs d'integration + la palette de marqueurs par categorie. |
| `LaTraceExample/MapViewController.swift` | Init de la carte, push des lieux, ecoute des evenements, recherche de lieu, vignette statique, bouton « rechercher dans cette zone ». |
| `LaTraceExample/PoiCardView.swift` | La fiche, cote hote. Rien de La Trace : la carte n'ouvre aucun panneau. |
| `LaTraceExample/AppDelegate.swift`, `SceneDelegate.swift` | Amorcage UIKit standard, sans rien de La Trace : ils installent `MapViewController` comme ecran racine. |
| `LaTraceExample/Resources/sample-pois.json` | Jeu de donnees d'exemple, a remplacer par votre API. |
| `project.yml` | Projet Xcode (XcodeGen) + dependance SwiftPM vers le SDK. |

## Personnaliser les marqueurs

- `ConfigOverride.poiColors` : couleur du marqueur, keyee par **categorie hote**
  (`Poi.category`). Source unique : la vignette statique relit la meme table.
- `ConfigOverride.poiIcons` : remplace le glyphe par **votre logo**, keye par `poiType`
  puis par categorie. Valeurs acceptees par la carte : URL `https` ou data URI SVG.
  **Pour avoir ce logo aussi sur la vignette statique, il faut une URL `https`** : la
  carte rend le data URI dans le navigateur embarque, la vignette est composee par le
  serveur, qui ne sait que fetcher une URL. `laTraceStaticMapRequest` filtre donc les
  data URI au lieu de les envoyer pour rien.
- `poiDetailMode: .hostHandled` : obligatoire des lors que vous affichez votre propre
  fiche. Le defaut de l'embed (`panel`) ouvrirait un panneau invisible sous le mode nu,
  et le marqueur tape resterait emphase indefiniment.

## Trois pieges du mode natif

- **`searchArea` n'arrive jamais.** Le SDK charge la carte en mode nu, ou le bouton
  « rechercher dans cette zone » de l'embed est masque : il n'emet donc pas cet
  evenement. Le signal a utiliser est `onViewportChange` (il n'y a pas d'evenement
  `idle` distinct), avec votre propre bouton. C'est ce que fait
  `MapViewController.handleViewport(_:)`.
- **Un `Padding` partiel n'est pas un padding partiel.** Un cote laisse a `nil` est
  envoye comme `0`, il ne retombe pas sur le padding de l'embed. Pour degager une
  bottom sheet sans coller les marqueurs aux trois autres bords, renseignez les quatre
  cotes ; pour garder le defaut de l'embed (40 px partout en mode nu), ne passez pas
  de padding du tout.
- **iOS peut tuer le process web sous vos pieds**, et le SDK recharge alors la carte
  vierge : corpus, cadrage et marqueur selectionne sont perdus tous les trois. Le SDK
  previent par `onReloaded` mais ne rejoue rien, et la carte ne rend pas son etat :
  c'est a l'hote de garder ce qu'il a pousse pour le repousser. C'est ce que font
  `pushedPois` / `lastViewport` / `selectedPoiId` dans `MapViewController`. N'appelez
  pas `trackOpen()` la : l'embed a redemarre, son ouverture est deja comptee.

## Cles et secrets

Sur iOS il n'y a pas de « cote serveur » : **tout ce qui est dans le binaire est
lisible**, y compris une valeur planquee dans un `.plist` ou un `.xcconfig`. La regle
est donc simple.

- La cle publiable (`pk_test_*` en preprod, `pk_live_*` en production) **peut** vivre
  dans l'app : elle est publiable par construction. La barriere n'est pas le secret,
  c'est le couple cle + quota + `configId`.
- Le secret HMAC de signature des cartes statiques **ne peut pas** : il signe des URL
  au nom de votre compte. Il n'a sa place que sur un serveur.
- Et vous n'en avez pas besoin ici. La signature (`?key=` + `sig` + `exp`) n'existe que
  pour un `<img>` de navigateur, qui ne sait pas poser d'en-tete. Un client natif, si :
  `laTraceStaticMapRequest` authentifie par l'en-tete `X-LaTrace-Key`, sans signature
  et sans secret. Montage correct en natif : la cle publiable, rien d'autre.
- Si votre application sert aussi des pages web avec la meme cle, c'est ce chemin web
  qui a besoin d'un backend de signature, pas l'app.

## Contrat d'API

Le format exact d'un `Poi`, les commandes et les evenements du pont, ainsi que les
endpoints REST sont decrits dans le **contrat d'API**, qui fait foi. Ce depot n'en
embarque volontairement pas de copie : une copie diverge et vous mettrait sur une
fausse piste. Le lien vous est fourni avec vos identifiants. La version du SDK epinglee
dans `project.yml` vous dit
a quelle revision du contrat cet exemple se refere ; le SDK Swift n'en implemente que
le sous-ensemble « carte pilotee » (pas de panneau, pas de recherche, pas de filtres
ouverts par la carte).

## Ce que l'exemple ne montre pas

- **La geolocalisation.** `LaTraceLocationProvider` (CoreLocation) alimente
  `map.setUserLocation(_:)` ; il faut declarer `NSLocationWhenInUseUsageDescription`
  dans l'`Info.plist`. Voir le README du SDK.
- **Le prechauffage.** Si la carte n'est pas le premier ecran, `prewarm: true` monte la
  vue cachee (dimensionnee, jamais `display:none`) et `map.activateMap(initialBBox:)`
  la revele au moment ou l'ecran carte apparait.
- **Le comptage des re-ouvertures.** La premiere ouverture est comptee toute seule.
  `map.trackOpen()` ne sert qu'a compter une re-ouverture sur une vue **reutilisee**
  (retour sur l'onglet carte) ; l'appeler ailleurs compte deux fois.

## Limites rencontrees en ecrivant cet exemple

Notees ici parce qu'elles se voient a l'usage, pas dans la doc du SDK.

1. **`Locale` du SDK masque `Foundation.Locale`.** Dans un fichier qui importe les
   deux, `Locale` seul est ambigu : il faut ecrire `LaTraceMapSDK.Locale.fr`, ou se
   reposer sur l'inference (`locale: .fr`), ce que fait cet exemple.
2. **`LocalizedString` n'est pas un litteral de chaine.** Un nom simple s'ecrit
   `name: .plain(titre)`, jamais `name: titre`.
3. **Pas d'assistant de bbox.** `BBox` et `LngLat` sont des `[Double]` nus : le calcul
   de la bbox d'un corpus et le test d'appartenance sont a la charge de l'hote (ils
   sont dans `MapViewController`, section « Geometrie »).
4. **Pas d'equivalent Swift de `categoryLabels` / `wording`.** `ConfigOverride` ne les
   expose pas ; sans consequence en mode nu, ou ce chrome n'est pas rendu.
5. **Rien pour restaurer l'etat apres `onReloaded`.** Le SDK documente que le corpus,
   la camera et la selection sont perdus, mais n'expose ni relecture de l'etat de la
   carte ni rejeu automatique : l'hote doit tenir lui-meme ces trois choses. C'est le
   seul endroit de cet exemple ou l'integrateur paie un etat en double.
