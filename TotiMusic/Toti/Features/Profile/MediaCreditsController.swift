import UIKit

/// The current bundled media register, distinct from fictional social profiles.
final class MediaCreditsController: StackScreen {
  private struct Credit: Decodable {
    let title: String
    let author: String?
    let sourceURL: String
    let licenseURL: String
  }

  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Media credits"
    heading("The people behind the pictures")
    content.addArrangedSubview(label(
      "Films and photos are licensed artwork. Photographed people are not represented as Toti members or endorsers. Profile names and conversations are authored content.",
      15, TotiTheme.muted))
    content.addArrangedSubview(label(
      "The included Pexels music recordings have no audio track. Icons, the app mark and the welcome illustration were created with an image generation model.",
      15, TotiTheme.muted))
    guard let url = Bundle.main.url(forResource: "MediaCredits", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let credits = try? JSONDecoder().decode([Credit].self, from: data)
    else {
      content.addArrangedSubview(label("Media credits could not be opened.", 16, TotiTheme.muted))
      return
    }
    for credit in credits {
      let body = stack([
        label(credit.title, 17, title: true),
        label(credit.author ?? "Author listed on source page", 14, TotiTheme.muted),
        actionButton("View source", icon: .info) {
          guard let source = URL(string: credit.sourceURL), source.scheme == "https" else { return }
          UIApplication.shared.open(source)
        },
      ], spacing: 6)
      content.addArrangedSubview(body)
    }
    content.addArrangedSubview(actionButton("Pexels License", icon: .info) {
      guard let url = URL(string: "https://www.pexels.com/license/") else { return }
      UIApplication.shared.open(url)
    })
  }
}
