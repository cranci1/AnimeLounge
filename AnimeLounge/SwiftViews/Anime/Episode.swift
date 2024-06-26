//
//  Episode.swift
//  AnimeLounge
//
//  Created by Francesco on 25/06/24.
//

import UIKit

struct Episode {
    let number: String
    let href: String
    let downloadUrl: String
}

class EpisodeCell: UITableViewCell {
    let episodeLabel = UILabel()
    let downloadButton = UIButton(type: .system)
    let startnowLabel = UILabel()
    let progressView = CircularProgressView()
    
    private var downloadProgress: Float = 0.0
    private var downloadTask: URLSessionDownloadTask?
    private var episodeNumber: String = ""
    private var fileName: String = ""
    private var downloadUrl: String = ""
    
    let playbackProgressView = UIProgressView(progressViewStyle: .default)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        contentView.backgroundColor = UIColor.secondarySystemBackground
        
        contentView.addSubview(episodeLabel)
        contentView.addSubview(downloadButton)
        contentView.addSubview(startnowLabel)
        contentView.addSubview(progressView)
        contentView.addSubview(playbackProgressView)
        
        episodeLabel.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        startnowLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        playbackProgressView.translatesAutoresizingMaskIntoConstraints = false
        
        episodeLabel.font = UIFont.systemFont(ofSize: 16)
        
        startnowLabel.font = UIFont.systemFont(ofSize: 13)
        startnowLabel.text = "Start Now"
        startnowLabel.textColor = .secondaryLabel
        
        downloadButton.setImage(UIImage(systemName: "icloud.and.arrow.down"), for: .normal)
        downloadButton.tintColor = .systemTeal
        downloadButton.addTarget(self, action: #selector(downloadButtonTapped), for: .touchUpInside)
        
        progressView.isHidden = true
        
        NSLayoutConstraint.activate([
            episodeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            episodeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            
            startnowLabel.leadingAnchor.constraint(equalTo: episodeLabel.leadingAnchor),
            startnowLabel.topAnchor.constraint(equalTo: episodeLabel.bottomAnchor, constant: 5),
            
            downloadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            downloadButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            downloadButton.widthAnchor.constraint(equalToConstant: 30),
            downloadButton.heightAnchor.constraint(equalToConstant: 30),
            
            progressView.centerXAnchor.constraint(equalTo: downloadButton.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: downloadButton.centerYAnchor),
            progressView.widthAnchor.constraint(equalToConstant: 30),
            progressView.heightAnchor.constraint(equalToConstant: 30),
            
            playbackProgressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            playbackProgressView.centerYAnchor.constraint(equalTo: startnowLabel.centerYAnchor),
            playbackProgressView.widthAnchor.constraint(equalToConstant: 150),
            
            contentView.bottomAnchor.constraint(equalTo: startnowLabel.bottomAnchor, constant: 10)
        ])
    }
    
    func updatePlaybackProgress(progress: Float) {
        playbackProgressView.isHidden = false
        startnowLabel.isHidden = true
        playbackProgressView.progress = progress
    }
    
    func resetPlaybackProgress() {
        playbackProgressView.isHidden = true
        startnowLabel.isHidden = false
        playbackProgressView.progress = 0.0
    }
    
    func loadSavedProgress(for fullURL: String) {
        let lastPlayedTime = UserDefaults.standard.double(forKey: "lastPlayedTime_\(fullURL)")
        let totalTime = UserDefaults.standard.double(forKey: "totalTime_\(fullURL)")
        
        if totalTime > 0 {
            let progress = Float(lastPlayedTime / totalTime)
            updatePlaybackProgress(progress: progress)
            playbackProgressView.isHidden = false
            startnowLabel.isHidden = true
        } else {
            resetPlaybackProgress()
            playbackProgressView.isHidden = true
            startnowLabel.isHidden = false
        }
    }

    func configure(episodeNumber: String, downloadUrl: String) {
        self.episodeNumber = episodeNumber
        self.downloadUrl = downloadUrl
        updateEpisodeLabel()
    }
    
    private func updateEpisodeLabel() {
        let mediaSource = UserDefaults.standard.string(forKey: "selectedMediaSource") ?? "AnimeHeaven"
        switch mediaSource {
        case "AnimeHeaven", "AnimeFire", "Latanime":
            episodeLabel.text = "\(episodeNumber)"
        default:
            episodeLabel.text = "Episode \(episodeNumber)"
        }
    }
    
    @objc private func downloadButtonTapped() {
        guard let url = URL(string: downloadUrl) else { return }
        fileName = "episode\(episodeNumber).mp4"
        startDownload(url: url)
    }
    
    func startDownload(url: URL) {
        downloadButton.isHidden = true
        progressView.isHidden = false
        downloadProgress = 0.0
        progressView.progress = downloadProgress
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    private func downloadCompleted() {
        downloadButton.isHidden = false
        progressView.isHidden = true
        downloadButton.setImage(UIImage(systemName: "checkmark.circle"), for: .normal)
        downloadButton.tintColor = .systemGreen
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension EpisodeCell: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard !fileName.isEmpty else { return }
        
        let destinationURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            print("File saved successfully: \(destinationURL.path)")
            
            DispatchQueue.main.async {
                self.downloadCompleted()
            }
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
            self.progressView.progress = self.downloadProgress        }
    }
}

class CircularProgressView: UIView {
    private let progressLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()
    
    var progress: Float = 0 {
        didSet {
            updateProgress()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        trackLayer.lineWidth = 3
        layer.addSublayer(trackLayer)
        
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemTeal.cgColor
        progressLayer.lineWidth = 3
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - progressLayer.lineWidth / 2
        
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi
        
        let circularPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        trackLayer.path = circularPath.cgPath
        progressLayer.path = circularPath.cgPath
        
        updateProgress()
    }
    
    private func updateProgress() {
        progressLayer.strokeEnd = CGFloat(progress)
    }
}

