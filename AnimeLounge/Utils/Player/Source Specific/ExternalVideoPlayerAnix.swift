//
//  ExternalVideoPlayerAnix.swift
//  AnimeLounge
//
//  Created by Francesco on 02/08/24.
//

import AVKit
import WebKit
import SwiftSoup
import GoogleCast

class ExternalVideoPlayerAnix: UIViewController, GCKRemoteMediaClientListener {
    private let streamURL: String
    private var webView: WKWebView?
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var activityIndicator: UIActivityIndicatorView?
    
    private var retryCount = 0
    private let maxRetries: Int
    
    private var cell: EpisodeCell
    private var fullURL: String
    private weak var animeDetailsViewController: AnimeDetailViewController?
    private var timeObserverToken: Any?

    init(streamURL: String, cell: EpisodeCell, fullURL: String, animeDetailsViewController: AnimeDetailViewController) {
        self.streamURL = streamURL
        self.cell = cell
        self.fullURL = fullURL
        self.animeDetailsViewController = animeDetailsViewController
        
        let userDefaultsRetries = UserDefaults.standard.integer(forKey: "maxRetries")
        self.maxRetries = userDefaultsRetries > 0 ? userDefaultsRetries : 10

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadInitialURL()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanup()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.secondarySystemBackground
        setupActivityIndicator()
        setupWebView()
    }
    
    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator?.color = .label
        activityIndicator?.startAnimating()
        activityIndicator?.center = view.center
        if let activityIndicator = activityIndicator {
            view.addSubview(activityIndicator)
        }
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    private func loadInitialURL() {
        guard let url = URL(string: streamURL) else {
            print("Invalid stream URL")
            return
        }
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    private func clickVidstreamSpan() {
        let script = """
            function clickMoonFSpan() {
                var spans = document.getElementsByTagName('span');
                for (var i = 0; i < spans.length; i++) {
                    if (spans[i].textContent.trim() === 'MoonF') {
                        spans[i].click();
                        return true;
                    }
                }
                return false;
            }
            clickMoonFSpan();
        """
        
        webView?.evaluateJavaScript(script) { [weak self] (result, error) in
            if let error = error {
                print("Error executing JavaScript: \(error.localizedDescription)")
                self?.retryExtraction()
            } else if let clicked = result as? Bool, clicked {
                print("MoonF span clicked successfully")
                self?.waitForVideoToLoad()
            } else {
                print("MoonF span not found")
                self?.retryExtraction()
            }
        }
    }
    
    private func waitForVideoToLoad() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.fetchAndPrintIframes()
        }
    }
    
    private func fetchAndPrintIframes() {
        let script = """
            var iframes = document.getElementsByTagName('iframe');
            var iframeInfo = [];
            for (var i = 0; i < iframes.length; i++) {
                iframeInfo.push({
                    src: iframes[i].src,
                    id: iframes[i].id,
                    class: iframes[i].className
                });
            }
            JSON.stringify(iframeInfo);
        """
        
        webView?.evaluateJavaScript(script) { [weak self] (result, error) in
            if let error = error {
                print("Error fetching iframes: \(error.localizedDescription)")
                self?.retryExtraction()
            } else if let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let iframes = try? JSONDecoder().decode([IframeInfo].self, from: data) {
                print("Iframes found:")
                for (index, iframe) in iframes.enumerated() {
                    print("Iframe \(index + 1):")
                    print("  Src: \(iframe.src)")
                    print("  ID: \(iframe.id)")
                    print("  Class: \(iframe.class)")
                    print("--------------------")
                }
                
                if let firstIframeSrc = iframes.first?.src {
                    self?.extractVideoFromIframe(src: firstIframeSrc)
                } else {
                    print("No iframes found")
                    self?.retryExtraction()
                }
            } else {
                print("Failed to parse iframe information")
                self?.retryExtraction()
            }
        }
    }
    
    private func extractVideoFromIframe(src: String) {
        guard let url = URL(string: src) else {
            print("Invalid iframe src")
            retryExtraction()
            return
        }
        
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    private func extractVideoSource() {
        webView?.evaluateJavaScript("document.querySelector('video')?.src") { [weak self] (result, error) in
            guard let self = self, let videoSrc = result as? String, let videoURL = URL(string: videoSrc) else {
                print("Error getting video source: \(error?.localizedDescription ?? "Unknown error")")
                self?.retryExtraction()
                return
            }
            
            print("Video source URL found: \(videoURL.absoluteString)")
            self.playVideo(url: videoURL)
        }
    }
    
    private func playVideo(url: URL) {
        DispatchQueue.main.async {
            self.activityIndicator?.stopAnimating()
            
            if UserDefaults.standard.bool(forKey: "isToDownload") {
                UserDefaults.standard.set(false, forKey: "isToDownload")
                
                self.dismiss(animated: true, completion: nil)
                
                let downloadManager = DownloadManager.shared
                let title = self.animeDetailsViewController?.animeTitle ?? "Anime Download"
                
                downloadManager.startDownload(url: url, title: title, progress: { progress in
                    DispatchQueue.main.async {
                        print("Download progress: \(progress * 100)%")
                    }
                }) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let downloadURL):
                            print("Download completed. File saved at: \(downloadURL)")
                            self?.animeDetailsViewController?.showAlert(withTitle: "Download Completed!", message: "You can find your download in the Library -> Downloads.")
                        case .failure(let error):
                            print("Download failed with error: \(error.localizedDescription)")
                            self?.animeDetailsViewController?.showAlert(withTitle: "Download Failed", message: error.localizedDescription)
                        }
                    }
                }
            } else {
                self.playOrCastVideo(url: url)
            }
        }
    }

    private func playOrCastVideo(url: URL) {
        if GCKCastContext.sharedInstance().sessionManager.currentCastSession != nil {
            self.castVideoToGoogleCast(videoURL: url)
            self.dismiss(animated: true, completion: nil)
        } else {
            let player = AVPlayer(url: url)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            self.addChild(playerViewController)
            self.view.addSubview(playerViewController.view)
            playerViewController.view.frame = self.view.bounds
            playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            playerViewController.didMove(toParent: self)
            
            let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(self.fullURL)")
            if lastPlayedTime > 0 {
                player.seek(to: CMTime(seconds: lastPlayedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
            }
            
            player.play()
            
            self.player = player
            self.playerViewController = playerViewController
            
            self.addPeriodicTimeObserver()
        }
    }
    
    private func addPeriodicTimeObserver() {
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
            let remainingTime = duration - currentTime
            
            self.cell.updatePlaybackProgress(progress: Float(progress), remainingTime: remainingTime)
            
            UserDefaults.standard.set(currentTime, forKey: "lastPlayedTime_\(self.fullURL)")
            UserDefaults.standard.set(duration, forKey: "totalTime_\(self.fullURL)")
            
            if remainingTime < 90 && !(self.animeDetailsViewController!.hasSentUpdate) {
                let cleanedTitle = self.animeDetailsViewController?.cleanTitle(self.animeDetailsViewController?.animeTitle ?? "Unknown Anime")
                
                self.animeDetailsViewController?.fetchAnimeID(title: cleanedTitle ?? "Title") { animeID in
                    let aniListMutation = AniListMutation()
                    aniListMutation.updateAnimeProgress(animeId: animeID, episodeNumber: Int(self.cell.episodeNumber) ?? 0) { result in
                        switch result {
                        case .success():
                            print("Successfully updated anime progress.")
                        case .failure(let error):
                            print("Failed to update anime progress: \(error.localizedDescription)")
                        }
                    }
                    
                    self.animeDetailsViewController?.hasSentUpdate = true
                }
            }
        }
    }

    private func castVideoToGoogleCast(videoURL: URL) {
        DispatchQueue.main.async {
            let metadata = GCKMediaMetadata(metadataType: .movie)
            
            if UserDefaults.standard.bool(forKey: "fullTitleCast") {
                if let animeTitle = self.animeDetailsViewController?.animeTitle {
                    metadata.setString(animeTitle, forKey: kGCKMetadataKeyTitle)
                } else {
                    print("Error: Anime title is missing.")
                }
            } else {
                let episodeNumber = (self.animeDetailsViewController?.currentEpisodeIndex ?? -1) + 1
                metadata.setString("Episode \(episodeNumber)", forKey: kGCKMetadataKeyTitle)
            }
            
            if UserDefaults.standard.bool(forKey: "animeImageCast") {
                if let imageURL = URL(string: self.animeDetailsViewController?.imageUrl ?? "") {
                    metadata.addImage(GCKImage(url: imageURL, width: 480, height: 720))
                } else {
                    print("Error: Anime image URL is missing or invalid.")
                }
            }
            
            let builder = GCKMediaInformationBuilder(contentURL: videoURL)
            builder.contentType = "application/x-mpegURL"
            builder.metadata = metadata
            
            let streamTypeString = UserDefaults.standard.string(forKey: "castStreamingType") ?? "buffered"
            switch streamTypeString {
            case "live":
                builder.streamType = .live
            default:
                builder.streamType = .buffered
            }
            
            let mediaInformation = builder.build()
            
            if let remoteMediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient {
                remoteMediaClient.loadMedia(mediaInformation)
            }
        }
    }
    
    private func retryExtraction() {
        retryCount += 1
        if retryCount < maxRetries {
            print("Retrying extraction (Attempt \(retryCount + 1))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.clickVidstreamSpan()
            }
        } else {
            print("Max retries reached. Unable to find video source.")
            DispatchQueue.main.async {
                self.activityIndicator?.stopAnimating()
                self.dismiss(animated: true)
            }
        }
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
        
        playerViewController?.willMove(toParent: nil)
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()
        playerViewController = nil
        
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        webView?.stopLoading()
        webView?.loadHTMLString("", baseURL: nil)
    }
}

extension ExternalVideoPlayerAnix: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url?.absoluteString == streamURL {
            clickVidstreamSpan()
        } else {
            extractVideoSource()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error.localizedDescription)")
        retryExtraction()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView provisional navigation failed: \(error.localizedDescription)")
        retryExtraction()
    }
}

struct IframeInfo: Codable {
    let src: String
    let id: String
    let `class`: String
}
