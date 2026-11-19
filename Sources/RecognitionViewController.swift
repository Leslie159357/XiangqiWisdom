import UIKit
import PhotosUI

/// 识别验证页：选一张棋盘截图 → 跑 BoardDetector / PieceDetector → 叠加检测框 + 输出 FEN
final class RecognitionViewController: UIViewController, PHPickerViewControllerDelegate {
    private let imageView = UIImageView()
    private let overlay = DetectionOverlayView()
    private let statusLabel = UILabel()
    private let fenLabel = UILabel()
    private let pickButton = UIButton(type: .system)
    private let pipButton = UIButton(type: .system)
    private let pip = PiPController()

    private lazy var boardDetector = Models.board()
    private lazy var pieceDetector = Models.pieces()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
        setupReceiver()
    }

    private var lastFrameAt: TimeInterval = 0

    private func setupReceiver() {
        BroadcastReceiver.shared.onFrame = { [weak self] image in
            guard let self = self else { return }
            let now = Date().timeIntervalSince1970
            guard now - self.lastFrameAt > 0.8 else { return }
            self.lastFrameAt = now
            self.run(on: image)
        }
        BroadcastReceiver.shared.start()
    }

    private func buildUI() {
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = modelStatus()
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        fenLabel.text = "FEN：—"
        fenLabel.textColor = .systemYellow
        fenLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        fenLabel.numberOfLines = 2
        fenLabel.translatesAutoresizingMaskIntoConstraints = false

        pickButton.setTitle("选择棋盘截图", for: .normal)
        pickButton.setTitleColor(.white, for: .normal)
        pickButton.backgroundColor = UIColor(red: 0.16, green: 0.60, blue: 0.33, alpha: 1)
        pickButton.layer.cornerRadius = 20
        pickButton.addTarget(self, action: #selector(pickTapped), for: .touchUpInside)
        pickButton.translatesAutoresizingMaskIntoConstraints = false

        pipButton.setTitle("画中画", for: .normal)
        pipButton.setTitleColor(.white, for: .normal)
        pipButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.75)
        pipButton.layer.cornerRadius = 20
        pipButton.addTarget(self, action: #selector(pipTapped), for: .touchUpInside)
        pipButton.translatesAutoresizingMaskIntoConstraints = false

        let back = UIButton(type: .system)
        back.setTitle("‹ 返回", for: .normal)
        back.setTitleColor(.white, for: .normal)
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        back.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(back)
        view.addSubview(imageView)
        view.addSubview(overlay)
        view.addSubview(statusLabel)
        view.addSubview(fenLabel)
        view.addSubview(pickButton)
        view.addSubview(pipButton)

        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),

            imageView.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),

            overlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: fenLabel.topAnchor, constant: -6),

            fenLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fenLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            fenLabel.bottomAnchor.constraint(equalTo: pickButton.topAnchor, constant: -10),

            pickButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pickButton.widthAnchor.constraint(equalToConstant: 200),
            pickButton.heightAnchor.constraint(equalToConstant: 44),
            pickButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            pipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pipButton.centerYAnchor.constraint(equalTo: pickButton.centerYAnchor),
            pipButton.widthAnchor.constraint(equalToConstant: 96),
            pipButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func modelStatus() -> String {
        let b = boardDetector != nil ? "BoardDetector ✓" : "BoardDetector ✗"
        let p = pieceDetector != nil ? "PieceDetector ✓" : "PieceDetector ✗"
        return "模型加载：\(b)   \(p)"
    }

    @objc private func backTapped() { dismiss(animated: true) }

    @objc private func pipTapped() {
        pip.attach(to: overlay)
        pip.start()
    }

    @objc private func pickTapped() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async { self?.run(on: image) }
        }
    }

    private func run(on image: UIImage) {
        imageView.image = image
        overlay.detections = []
        fenLabel.text = "FEN：计算中…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let boards = self.boardDetector?.detect(in: image) ?? []
            let pieces = self.pieceDetector?.detect(in: image) ?? []
            let all = boards + pieces
            let fen = FENMapper.fen(from: all)
            var bookText = "开局库：未命中"
            if let grid = FENMapper.board(from: all),
               let key = Zobrist.shared.key(board: grid, redGo: true) {
                if let best = OpeningBook.shared.bestMove(key: key),
                   let uci = Zobrist.shared.uciMove(vmove: best.vmove) {
                    bookText = "开局库：\(uci) · 评分 \(best.score) · \(best.win)胜\(best.draw)和\(best.lost)负"
                } else {
                    bookText = "开局库：该局面未收录（key \(String(key, radix: 16))）"
                }
            }
            DispatchQueue.main.async {
                self.overlay.detections = all
                let counts = Dictionary(grouping: all, by: { $0.label }).map { "\($0.key):\($0.value.count)" }
                self.statusLabel.text = "检测到 \(all.count) 个目标  " + counts.sorted().joined(separator: " ")
                    + "\n" + bookText
                self.fenLabel.text = fen.map { "FEN：\($0)" } ?? "FEN：未找到棋盘（bd）"
            }
        }
    }
}

/// 在图片上叠加归一化坐标的检测框
final class DetectionOverlayView: UIView {
    var detections: [Detection] = [] {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let imageRect = aspectFitRect(for: rect)
        context.setLineWidth(2)
        for d in detections {
            let r = CGRect(x: imageRect.minX + d.rect.minX * imageRect.width,
                           y: imageRect.minY + d.rect.minY * imageRect.height,
                           width: d.rect.width * imageRect.width,
                           height: d.rect.height * imageRect.height)
            let isBoard = d.label == "bd" || d.label == "dt" || d.label == "dk"
            context.setStrokeColor((isBoard ? UIColor.systemYellow : UIColor.systemRed).cgColor)
            context.stroke(r)
        }
    }

    private func aspectFitRect(for bounds: CGRect) -> CGRect {
        guard let image = (superview?.subviews.compactMap { $0 as? UIImageView }.first?.image) else { return bounds }
        let imageAspect = image.size.width / image.size.height
        let boundsAspect = bounds.width / bounds.height
        if imageAspect > boundsAspect {
            let h = bounds.width / imageAspect
            return CGRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        } else {
            let w = bounds.height * imageAspect
            return CGRect(x: (bounds.width - w) / 2, y: 0, width: w, height: bounds.height)
        }
    }
}
