import UIKit

/// 设置页：复刻原版五项入口（对局推演 / 配置引擎 / 浮窗样式 / 语音提示 / 更多设置）。
final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let rows: [(title: String, detail: String)] = [
        ("对局推演", "皮卡鱼象棋"),
        ("配置引擎", "皮卡鱼 · 1秒"),
        ("浮窗样式", "小棋盘"),
        ("语音提示", "开"),
        ("更多设置", "")
    ]

    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let voice = VoiceCoach()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.33, green: 0.22, blue: 0.13, alpha: 1)

        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)

        let header = makeHeader()
        view.addSubview(header)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),
            table.topAnchor.constraint(equalTo: header.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let back = UIButton(type: .system)
        back.setTitle("‹ 返回", for: .normal)
        back.setTitleColor(.white, for: .normal)
        back.titleLabel?.font = .systemFont(ofSize: 16)
        back.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        back.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(back)

        let title = UILabel()
        title.text = "设置"
        title.textColor = .white
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(title)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
            back.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            title.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        return header
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = UIListContentConfiguration.valueCell()
        config.text = rows[indexPath.row].title
        config.secondaryText = rows[indexPath.row].detail
        config.textProperties.color = .label
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch rows[indexPath.row].title {
        case "对局推演":
            runDemo()
        case "语音提示":
            voice.say("语音提示已开启")
            toast("语音提示：开")
        default:
            toast(rows[indexPath.row].detail.isEmpty ? rows[indexPath.row].title : rows[indexPath.row].detail)
        }
    }

    private func runDemo() {
        EngineBridge.shared.bestMove(fen: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w") { [weak self] result in
            switch result {
            case .success(let move):
                self?.toast("最佳着法：\(move)")
                self?.voice.say("最佳着法 \(move)")
            case .failure(let error):
                self?.toast("引擎未就绪：\(error.localizedDescription)")
            }
        }
    }

    private func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }
}
