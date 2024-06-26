//
//  AnimeDetailsViewController.swift
//  AnimeLounge
//
//  Created by Francesco on 22/06/24.
//

import UIKit
import AVKit
import WebKit
import SwiftSoup
import GoogleCast

extension String {
    var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
}

class AnimeDetailViewController: UITableViewController, WKNavigationDelegate, GCKRemoteMediaClientListener {
    private var animeTitle: String?
    private var imageUrl: String?
    private var href: String?
    
    private var episodes: [Episode] = []
    private var synopsis: String = ""
    private var aliases: String = ""
    private var airdate: String = ""
    private var stars: String = ""
    
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var currentEpisodeIndex: Int = 0
    
    private var timeObserverToken: Any?
    
    private var isFavorite: Bool = false
    private var isSynopsisExpanded = false

    func configure(title: String, imageUrl: String, href: String) {
        self.animeTitle = title
        self.imageUrl = imageUrl
        self.href = href
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
        setupNotifications()
        checkFavoriteStatus()
        setupCastButton()
        
        navigationController?.navigationBar.prefersLargeTitles = false
        
        for (index, episode) in episodes.enumerated() {
            if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 2)) as? EpisodeCell {
                cell.loadSavedProgress(for: episode.href)
            }
        }
        
        if let firstEpisodeHref = episodes.first?.href {
             currentEpisodeIndex = episodes.firstIndex(where: { $0.href == firstEpisodeHref }) ?? 0
         }
    }

    private func setupCastButton() {
        let castButton = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: castButton)
    }

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func toggleFavorite() {
        isFavorite.toggle()
        if let anime = createFavoriteAnime() {
            if isFavorite {
                FavoritesManager.shared.addFavorite(anime)
            } else {
                FavoritesManager.shared.removeFavorite(anime)
            }
        }
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
    
    private func createFavoriteAnime() -> FavoriteItem? {
        guard let title = animeTitle,
              let imageURL = URL(string: imageUrl ?? ""),
              let contentURL = URL(string: href ?? "") else {
            return nil
        }
        return FavoriteItem(title: title, imageURL: imageURL, contentURL: contentURL)
    }
    
    private func checkFavoriteStatus() {
        if let anime = createFavoriteAnime() {
            isFavorite = FavoritesManager.shared.isFavorite(anime)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .secondarySystemBackground
        tableView.register(AnimeHeaderCell.self, forCellReuseIdentifier: "AnimeHeaderCell")
        tableView.register(SynopsisCell.self, forCellReuseIdentifier: "SynopsisCell")
        tableView.register(EpisodeCell.self, forCellReuseIdentifier: "EpisodeCell")
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            player?.pause()
        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                player?.play()
            } catch {
                print("Failed to reactivate AVAudioSession: \(error)")
            }
        default:
            break
        }
    }

    private func updateUI() {
        if let href = href {
            AnimeDetailService.fetchAnimeDetails(from: href) { [weak self] (result) in
                switch result {
                case .success(let details):
                    self?.aliases = details.aliases
                    self?.synopsis = details.synopsis
                    self?.airdate = details.airdate
                    self?.stars = details.stars
                    self?.episodes = details.episodes
                    DispatchQueue.main.async {
                        self?.tableView.reloadData()
                    }
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0, 1: return 1
        case 2: return episodes.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AnimeHeaderCell", for: indexPath) as! AnimeHeaderCell
            cell.configure(title: animeTitle, imageUrl: imageUrl, aliases: aliases, isFavorite: isFavorite, airdate: airdate, stars: stars)
            cell.favoriteButtonTapped = { [weak self] in
                self?.toggleFavorite()
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SynopsisCell", for: indexPath) as! SynopsisCell
            cell.configure(synopsis: synopsis, isExpanded: isSynopsisExpanded)
            cell.delegate = self
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "EpisodeCell", for: indexPath) as! EpisodeCell
            let episode = episodes[indexPath.row]
            cell.configure(episodeNumber: episode.number, downloadUrl: episode.downloadUrl)
            cell.loadSavedProgress(for: episode.href)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 {
            let episode = episodes[indexPath.row]
            if let cell = tableView.cellForRow(at: indexPath) as? EpisodeCell {
                episodeSelected(episode: episode, cell: cell)
            }
        }
    }

    private func episodeSelected(episode: Episode, cell: EpisodeCell) {
        let selectedSource = UserDefaults.standard.string(forKey: "selectedMediaSource") ?? "AnimeHeaven"
        currentEpisodeIndex = episodes.firstIndex(where: { $0.href == episode.href }) ?? 0
        
        var baseURL: String
        var fullURL: String
        var episodeId: String
        var episodeTimeURL: String
        
        switch selectedSource {
        case "AnimeWorld":
            baseURL = "https://www.animeworld.so/api/episode/serverPlayerAnimeWorld?id="
            episodeId = episode.href.components(separatedBy: "/").last ?? episode.href
            fullURL = baseURL + episodeId
            episodeTimeURL = episode.href
            checkUserDefault(url: fullURL, cell: cell, fullURL: episodeTimeURL)
            return
        case "AnimeHeaven":
            baseURL = "https://animeheaven.me/"
            episodeId = episode.href
            fullURL = baseURL + episodeId
            checkUserDefault(url: fullURL, cell: cell, fullURL: fullURL)
            return
        case "AnimeFire", "Kuramanime", "Latanime":
            episodeId = episode.href
            fullURL = episodeId
            openWebView(fullURL: fullURL)
            return
        case "GoGoAnime":
            baseURL = "https://anitaku.pe/"
            episodeId = episode.href.components(separatedBy: "/").last ?? episode.href
            fullURL = baseURL + episodeId
            openWebView(fullURL: fullURL)
            return
        default:
            baseURL = ""
            episodeId = episode.href
            fullURL = baseURL + episodeId
            playEpisode(url: fullURL, cell: cell, fullURL: fullURL)
            return
        }
    }
    
    private func checkUserDefault(url: String, cell: EpisodeCell, fullURL: String) {
        if UserDefaults.standard.bool(forKey: "browserPlayer") {
            openWebView(fullURL: url)
        } else {
            playEpisode(url: url, cell: cell, fullURL: fullURL)
        }
    }
    
    private func openWebView(fullURL: String) {
        let webView = WKWebView(frame: view.bounds)
        webView.navigationDelegate = self
        view.addSubview(webView)
        
        if let url = URL(string: fullURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    private func fetchHTMLContent(from url: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "Invalid data", code: 0, userInfo: nil)))
                return
            }
            
            completion(.success(htmlString))
        }.resume()
    }

    private func playEpisode(url: String, cell: EpisodeCell, fullURL: String) {
        guard let videoURL = URL(string: url) else {
            print("Invalid URL")
            return
        }

        if GCKCastContext.sharedInstance().sessionManager.hasConnectedCastSession() {
            castVideoToGoogleCast(url: videoURL)
        } else {
            if url.contains(".mp4") || url.contains(".m3u8") || url.contains("animeheaven.me/video.mp4") {
                DispatchQueue.main.async {
                    self.playVideoWithAVPlayer(sourceURL: videoURL, cell: cell, fullURL: fullURL)
                }
            } else {
                URLSession.shared.dataTask(with: videoURL) { [weak self] (data, response, error) in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error fetching video data: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data,
                          let htmlString = String(data: data, encoding: .utf8),
                          let srcURL = self.extractVideoSourceURL(from: htmlString) else {
                        print("Error parsing video data")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.playVideoWithAVPlayer(sourceURL: srcURL, cell: cell, fullURL: fullURL)
                    }
                }.resume()
            }
        }
    }

    private func castVideoToGoogleCast(url: URL) {
        fetchHTMLContent(from: url.absoluteString) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let htmlString):
                    if let videoURL = self.extractVideoSourceURL(from: htmlString) {
                        self.proceedWithCasting(videoURL: videoURL)
                    } else {
                        print("Error: Could not extract video URL from the page")
                    }
                case .failure(let error):
                    print("Error fetching HTML content: \(error.localizedDescription)")
                }
            }
        }
    }

    private func proceedWithCasting(videoURL: URL) {
        DispatchQueue.main.async {
            guard let animeTitle = self.animeTitle else {
                print("Error: Anime title is missing.")
                return
            }

            let metadata = GCKMediaMetadata(metadataType: .movie)
            metadata.setString(animeTitle, forKey: kGCKMetadataKeyTitle)

            if let imageURL = URL(string: self.imageUrl ?? "") {
                metadata.addImage(GCKImage(url: imageURL, width: 480, height: 720))
            } else {
                print("Error: Anime image URL is missing or invalid.")
            }

            let contentType: String
            let streamType: GCKMediaStreamType

            if videoURL.absoluteString.contains(".m3u8") {
                contentType = "application/x-mpegurl"
                streamType = .live
            } else if videoURL.absoluteString.contains(".mp4") {
                contentType = "video/mp4"
                streamType = .buffered
            } else {
                contentType = "application/x-mpegurl"
                streamType = .buffered
            }

            let mediaInfo = GCKMediaInformation(
                contentID: videoURL.absoluteString,
                streamType: streamType,
                contentType: contentType,
                metadata: metadata,
                streamDuration: 0,
                mediaTracks: nil,
                textTrackStyle: nil,
                customData: nil
            )

            let mediaLoadOptions = GCKMediaLoadOptions()
            mediaLoadOptions.autoplay = true
            mediaLoadOptions.playPosition = 0

            if let castSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession,
               let remoteMediaClient = castSession.remoteMediaClient {
                remoteMediaClient.loadMedia(mediaInfo, with: mediaLoadOptions)
                remoteMediaClient.add(self)
            } else {
                print("Error: Failed to load media to Google Cast")
            }
        }
    }
    
    private func extractVideoSourceURL(from htmlString: String) -> URL? {
        do {
            let doc: Document = try SwiftSoup.parse(htmlString)
            guard let videoElement = try doc.select("video").first(),
                  let sourceElement = try videoElement.select("source").first(),
                  let sourceURLString = try sourceElement.attr("src").nilIfEmpty,
                  let sourceURL = URL(string: sourceURLString) else {
                return nil
            }
            return sourceURL
        } catch {
            print("Error parsing HTML with SwiftSoup: \(error)")
            
            let mp4Pattern = #"<source src="(.*?)" type="video/mp4">"#
            let m3u8Pattern = #"<source src="(.*?)" type="application/x-mpegURL">"#
            
            if let mp4URL = extractURL(from: htmlString, pattern: mp4Pattern) {
                return mp4URL
            } else if let m3u8URL = extractURL(from: htmlString, pattern: m3u8Pattern) {
                return m3u8URL
            }
            return nil
        }
    }
    
    private func extractURL(from htmlString: String, pattern: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)),
              let urlRange = Range(match.range(at: 1), in: htmlString) else {
            return nil
        }
        
        let urlString = String(htmlString[urlRange])
        return URL(string: urlString)
    }

    private func playVideoWithAVPlayer(sourceURL: URL, cell: EpisodeCell, fullURL: String) {
        player = AVPlayer(url: sourceURL)
        
        if UserDefaults.standard.bool(forKey: "AlwaysLandscape") {
            playerViewController = LandscapePlayer()
        } else {
            playerViewController = AVPlayerViewController()
        }
        
        playerViewController?.player = player
        
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullURL)")
        
        present(playerViewController!, animated: true) {
            if lastPlayedTime > 0 {
                let seekTime = CMTime(seconds: lastPlayedTime, preferredTimescale: 1)
                self.player?.seek(to: seekTime) { _ in
                    self.player?.play()
                }
            } else {
                self.player?.play()
            }
            self.addPeriodicTimeObserver(cell: cell, fullURL: fullURL)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }

    private func addPeriodicTimeObserver(cell: EpisodeCell, fullURL: String) {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let currentItem = self.player?.currentItem,
                  currentItem.duration.seconds.isFinite else {
                return
            }
            
            let currentTime = time.seconds
            let duration = currentItem.duration.seconds
            let progress = currentTime / duration
            
            cell.updatePlaybackProgress(progress: Float(progress))
            
            UserDefaults.standard.set(currentTime, forKey: "lastPlayedTime_\(fullURL)")
            UserDefaults.standard.set(duration, forKey: "totalTime_\(fullURL)")
        }
    }
    
    private func playNextEpisode() {
        currentEpisodeIndex += 1
        if currentEpisodeIndex < episodes.count {
            let nextEpisode = episodes[currentEpisodeIndex]
            if let cell = tableView.cellForRow(at: IndexPath(row: currentEpisodeIndex, section: 2)) as? EpisodeCell {
                episodeSelected(episode: nextEpisode, cell: cell)
            }
        } else {
            print("No more episodes to play")
        }
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) {        
        if UserDefaults.standard.bool(forKey: "AutoPlay") {
            playerViewController?.dismiss(animated: true) { [weak self] in
                self?.playNextEpisode()
            }
        } else {
            playerViewController?.dismiss(animated: true, completion: nil)
        }
    }
}

extension AnimeDetailViewController: SynopsisCellDelegate {
    func synopsisCellDidToggleExpansion(_ cell: SynopsisCell) {
        isSynopsisExpanded.toggle()
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }
}

class AnimeHeaderCell: UITableViewCell {
    private let animeImageView = UIImageView()
    private let titleLabel = UILabel()
    private let aliasLabel = UILabel()
    private let favoriteButton = UIButton()
    private let starLabel = UILabel()
    private let airDateLabel = UILabel()
    private let starIconImageView = UIImageView()
    private let calendarIconImageView = UIImageView()
    
    var favoriteButtonTapped: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        
        contentView.addSubview(animeImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(aliasLabel)
        contentView.addSubview(favoriteButton)
        contentView.addSubview(starLabel)
        contentView.addSubview(airDateLabel)
        contentView.addSubview(starIconImageView)
        contentView.addSubview(calendarIconImageView)
        
        animeImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        aliasLabel.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        starLabel.translatesAutoresizingMaskIntoConstraints = false
        airDateLabel.translatesAutoresizingMaskIntoConstraints = false
        starIconImageView.translatesAutoresizingMaskIntoConstraints = false
        calendarIconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        animeImageView.contentMode = .scaleAspectFit
        
        titleLabel.font = UIFont.boldSystemFont(ofSize: 21)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 4

        aliasLabel.font = UIFont.systemFont(ofSize: 13)
        aliasLabel.textColor = .secondaryLabel
        aliasLabel.numberOfLines = 2

        favoriteButton.setTitle("FAVORITE", for: .normal)
        favoriteButton.setTitleColor(.black, for: .normal)
        favoriteButton.backgroundColor = UIColor.systemTeal
        favoriteButton.layer.cornerRadius = 14
        favoriteButton.addTarget(self, action: #selector(favoriteButtonPressed), for: .touchUpInside)
        
        starLabel.font = UIFont.boldSystemFont(ofSize: 15)
        starLabel.textColor = .secondaryLabel
        
        airDateLabel.font = UIFont.boldSystemFont(ofSize: 15)
        airDateLabel.textColor = .secondaryLabel
        
        starIconImageView.image = UIImage(systemName: "star.fill")
        starIconImageView.tintColor = .systemGray
        
        calendarIconImageView.image = UIImage(systemName: "calendar")
        calendarIconImageView.tintColor = .systemGray
        
        NSLayoutConstraint.activate([
            animeImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            animeImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            animeImageView.widthAnchor.constraint(equalToConstant: 110),
            animeImageView.heightAnchor.constraint(equalToConstant: 160),
            
            titleLabel.topAnchor.constraint(equalTo: animeImageView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: animeImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            
            aliasLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            aliasLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            aliasLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            favoriteButton.bottomAnchor.constraint(equalTo: animeImageView.bottomAnchor),
            favoriteButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            favoriteButton.heightAnchor.constraint(equalToConstant: 30),
            favoriteButton.widthAnchor.constraint(equalToConstant: 100),
            
            starIconImageView.topAnchor.constraint(equalTo: animeImageView.bottomAnchor, constant: 16),
            starIconImageView.leadingAnchor.constraint(equalTo: animeImageView.leadingAnchor),
            starIconImageView.widthAnchor.constraint(equalToConstant: 20),
            starIconImageView.heightAnchor.constraint(equalToConstant: 20),
             
            starLabel.bottomAnchor.constraint(equalTo: starIconImageView.bottomAnchor),
            starLabel.leadingAnchor.constraint(equalTo: starIconImageView.trailingAnchor),
             
            calendarIconImageView.topAnchor.constraint(equalTo: animeImageView.bottomAnchor, constant: 16),
            calendarIconImageView.trailingAnchor.constraint(equalTo: airDateLabel.leadingAnchor),
            calendarIconImageView.widthAnchor.constraint(equalToConstant: 20),
            calendarIconImageView.heightAnchor.constraint(equalToConstant: 20),
             
            airDateLabel.bottomAnchor.constraint(equalTo: calendarIconImageView.bottomAnchor),
            airDateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
             
            contentView.bottomAnchor.constraint(equalTo: calendarIconImageView.bottomAnchor, constant: 10)
        ])
    }
    
    @objc private func favoriteButtonPressed() {
        favoriteButtonTapped?()
    }
    
    func configure(title: String?, imageUrl: String?, aliases: String, isFavorite: Bool, airdate: String, stars: String) {
        titleLabel.text = title
        aliasLabel.text = aliases
        airDateLabel.text = airdate
        
        let selectedSource = UserDefaults.standard.string(forKey: "selectedMediaSource")
        
        switch selectedSource {
        case "AnimeWorld":
            starLabel.text = stars + "/10"
            airDateLabel.text = airdate
        case "GoGoAnime", "AnimeFire", "Latanime":
            starLabel.text = "N/A"
        default:
            starLabel.text = stars
            airDateLabel.text = airdate
        }
        
        if let url = URL(string: imageUrl ?? "") {
            animeImageView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        }
        updateFavoriteButtonState(isFavorite: isFavorite)
    }
    
    private func updateFavoriteButtonState(isFavorite: Bool) {
        let title = isFavorite ? "REMOVE" : "FAVORITE"
        favoriteButton.setTitle(title, for: .normal)
        favoriteButton.backgroundColor = isFavorite ? .systemGray : .systemTeal
    }
}


protocol SynopsisCellDelegate: AnyObject {
    func synopsisCellDidToggleExpansion(_ cell: SynopsisCell)
}

class SynopsisCell: UITableViewCell {
    private let synopsisLabel = UILabel()
    private let synopsyLabel = UILabel()
    private let toggleButton = UIButton()
    
    weak var delegate: SynopsisCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .secondarySystemBackground
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(synopsisLabel)
        contentView.addSubview(toggleButton)
        contentView.addSubview(synopsyLabel)
        
        synopsyLabel.text = "Synopsis"
        synopsyLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        synopsyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        synopsisLabel.numberOfLines = 4
        synopsisLabel.font = UIFont.systemFont(ofSize: 14)
        synopsisLabel.translatesAutoresizingMaskIntoConstraints = false
        
        toggleButton.setTitleColor(.systemTeal, for: .normal)
        toggleButton.addTarget(self, action: #selector(toggleButtonTapped), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        
        NSLayoutConstraint.activate([
            synopsyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            synopsyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            
            synopsisLabel.topAnchor.constraint(equalTo: synopsyLabel.bottomAnchor, constant: 5),
            synopsisLabel.leadingAnchor.constraint(equalTo: synopsyLabel.leadingAnchor),
            synopsisLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            synopsisLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            toggleButton.centerYAnchor.constraint(equalTo: synopsyLabel.centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15)
        ])
    }
    
    func configure(synopsis: String, isExpanded: Bool) {
        synopsisLabel.text = synopsis
        synopsisLabel.numberOfLines = isExpanded ? 0 : 4
        toggleButton.setTitle(isExpanded ? "Less" : "More", for: .normal)
    }
    
    @objc private func toggleButtonTapped() {
        delegate?.synopsisCellDidToggleExpansion(self)
    }
}
