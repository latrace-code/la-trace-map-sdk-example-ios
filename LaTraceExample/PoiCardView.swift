import UIKit

/// Fiche minimale de l'hote. Elle n'a rien de La Trace : la carte n'ouvre aucun
/// panneau (`poiDetailMode: .hostHandled`), elle signale seulement le tap. Toute
/// la fiche, sa mise en forme et son cycle de vie appartiennent a l'application.
final class PoiCardView: UIView {

    let thumbnail = UIImageView()
    var onClose: (() -> Void)?

    private let nameLabel = UILabel()
    private let addressLabel = UILabel()

    init() {
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PoiCardView does not support storyboard instantiation")
    }

    func show(name: String, address: String?) {
        nameLabel.text = name
        addressLabel.text = address
        thumbnail.image = nil
        isHidden = false
    }

    private func setUp() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 14
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        isHidden = true

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.numberOfLines = 2
        addressLabel.font = .preferredFont(forTextStyle: .footnote)
        addressLabel.textColor = .secondaryLabel
        addressLabel.numberOfLines = 2

        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.layer.cornerRadius = 8
        thumbnail.backgroundColor = .secondarySystemBackground

        let close = UIButton(type: .close)
        close.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        let texts = UIStackView(arrangedSubviews: [nameLabel, addressLabel])
        texts.axis = .vertical
        texts.spacing = 2

        let row = UIStackView(arrangedSubviews: [thumbnail, texts, close])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            thumbnail.widthAnchor.constraint(equalToConstant: 96),
            thumbnail.heightAnchor.constraint(equalToConstant: 72),
        ])
    }
}
