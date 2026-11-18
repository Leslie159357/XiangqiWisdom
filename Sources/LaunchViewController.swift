import UIKit

/// 启动页：复刻原版结构（标题 / 副标题 / 会员状态 / 启动按钮）。
/// 开源版没有服务端，本地会员态恒为已开通。
final class LaunchViewController: UIViewController {
    private let statusLabel = UILabel()
    private let startButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.33, green: 0.22, blue: 0.13, alpha: 1)
        buildUI()
    }

    private func buildUI() {
        let title = UILabel()
        title.text = "象 棋 智 囊"
        title.font = UIFont(name: "STKaiti", size: 34) ?? .boldSystemFont(ofSize: 34)
        title.textColor = .white
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "提升棋艺的好帮手"
        subtitle.font = .systemFont(ofSize: 15)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.75)
        subtitle.textAlignment = .center

        statusLabel.text = "正在查询会员状态"
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        statusLabel.textAlignment = .center

        startButton.setTitle("启动", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        startButton.backgroundColor = UIColor(red: 0.16, green: 0.60, blue: 0.33, alpha: 1)
        startButton.layer.cornerRadius = 22
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, subtitle, statusLabel, startButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(44, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -96),
            startButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.statusLabel.text = "会员已开通 · 终身有效"
        }
    }

    @objc private func startTapped() {
        let settings = SettingsViewController()
        settings.modalPresentationStyle = .fullScreen
        present(settings, animated: true)
    }
}
