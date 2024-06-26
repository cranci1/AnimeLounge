//
//  WatchNextViewController.swift
//  AnimeLounge
//
//  Created by Francesco on 21/06/24.
//

import UIKit

class WatchNextViewController: UITableViewController {
    
    @IBOutlet private weak var airingCollectionView: UICollectionView!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var seasonalCollectionView: UICollectionView!
    
    @IBOutlet weak var dateLabel: UILabel!
    
    private var airingAnime: [Anime] = []
    private var trendingAnime: [Anime] = []
    private var seasonalAnime: [Anime] = []
    
    private let aniListServiceAiring = AnilistServiceAiringAnime()
    private let aniListServiceTrending = AnilistServiceTrendingAnime()
    private let aniListServiceSeasonal = AnilistServiceSeasonalAnime()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionView()
        setupDateLabel()
        fetchAnimeData()
    }
    
    func setupCollectionView() {
        airingCollectionView.delegate = self
        airingCollectionView.dataSource = self
        airingCollectionView.register(UINib(nibName: "AiringAnimeCell", bundle: nil), forCellWithReuseIdentifier: "AiringAnimeCell")
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(UINib(nibName: "TrendingAnimeCell", bundle: nil), forCellWithReuseIdentifier: "TrendingAnimeCell")
        
        seasonalCollectionView.delegate = self
        seasonalCollectionView.dataSource = self
        seasonalCollectionView.register(UINib(nibName: "SeasonalAnimeCell", bundle: nil), forCellWithReuseIdentifier: "SeasonalAnimeCell")
    }
    
    func setupDateLabel() {
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, dd MMMM yyyy"
        let dateString = dateFormatter.string(from: currentDate)
        dateLabel.text = "on \(dateString)"
    }
    
    func fetchAnimeData() {
        fetchTrendingAnime()
        fetchSeasonalAnime()
        fetchAiringAnime()
    }
    
    func fetchTrendingAnime() {
        aniListServiceTrending.fetchTrendingAnime { [weak self] animeList in
            guard let self = self else { return }
            if let animeList = animeList {
                self.trendingAnime = animeList
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            } else {
                print("Failed to fetch trending anime")
            }
        }
    }
    
    func fetchSeasonalAnime() {
        aniListServiceSeasonal.fetchSeasonalAnime { [weak self] animeList in
            guard let self = self else { return }
            if let animeList = animeList {
                self.seasonalAnime = animeList
                DispatchQueue.main.async {
                    self.seasonalCollectionView.reloadData()
                }
            } else {
                print("Failed to fetch seasonal anime")
            }
        }
    }
    
    func fetchAiringAnime() {
        aniListServiceAiring.fetchAiringAnime { [weak self] animeList in
            guard let self = self else { return }
            if let animeList = animeList {
                self.airingAnime = animeList
                DispatchQueue.main.async {
                    self.airingCollectionView.reloadData()
                }
            } else {
                print("Failed to fetch seasonal anime")
            }
        }
    }
    
    @IBAction func selectSourceButtonTapped(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Select Source", message: "Choose your preferred source for AnimeLounge.", preferredStyle: .actionSheet)
        
        let worldAction = UIAlertAction(title: "AnimeWorld", style: .default) { _ in
            UserDefaults.standard.selectedMediaSource = .animeWorld
        }
        setUntintedImage(for: worldAction, named: "AnimeWorld")
        
        let gogoAction = UIAlertAction(title: "GoGoAnime", style: .default) { _ in
            UserDefaults.standard.selectedMediaSource = .gogoanime
        }
        setUntintedImage(for: gogoAction, named: "GoGoAnime")
        
        let heavenAction = UIAlertAction(title: "AnimeHeaven", style: .default) { _ in
            UserDefaults.standard.selectedMediaSource = .animeheaven
        }
        setUntintedImage(for: heavenAction, named: "AnimeHeaven")
        
        let fireAction = UIAlertAction(title: "AnimeFire", style: .default) { _ in
            UserDefaults.standard.selectedMediaSource = .animefire
        }
        setUntintedImage(for: fireAction, named: "AnimeFire")
        
        let kuraAction = UIAlertAction(title: "Kuramanime", style: .default) { _ in
            UserDefaults.standard.selectedMediaSource = .kuramanime
        }
        setUntintedImage(for: kuraAction, named: "Kuramanime")
        
        let latAction = UIAlertAction(title: "Latanime", style: .default) { _ in
            UserDefaults.standard.selectedMediaSource = .latanime
        }
        setUntintedImage(for: latAction, named: "Latanime")
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(worldAction)
        alertController.addAction(gogoAction)
        alertController.addAction(heavenAction)
        alertController.addAction(fireAction)
        alertController.addAction(kuraAction)
        alertController.addAction(latAction)
        alertController.addAction(cancelAction)
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    func setUntintedImage(for action: UIAlertAction, named imageName: String) {
        if let originalImage = UIImage(named: imageName) {
            let resizedImage = resizeImage(originalImage, targetSize: CGSize(width: 35, height: 35))
            if let untintedImage = resizedImage?.withRenderingMode(.alwaysOriginal) {
                action.setValue(untintedImage, forKey: "image")
            }
        }
    }
    
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

extension WatchNextViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.collectionView {
            return trendingAnime.count
        } else if collectionView == self.seasonalCollectionView {
            return seasonalAnime.count
        } else if collectionView == self.airingCollectionView {
            return airingAnime.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.collectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TrendingAnimeCell", for: indexPath) as! TrendingAnimeCell
            let anime = trendingAnime[indexPath.item]
            let imageUrl = URL(string: anime.coverImage.large)
            cell.configure(with: anime.title.romaji, imageUrl: imageUrl)
            return cell
        } else if collectionView == self.seasonalCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SeasonalAnimeCell", for: indexPath) as! SeasonalAnimeCell
            let anime = seasonalAnime[indexPath.item]
            let imageUrl = URL(string: anime.coverImage.large)
            cell.configure(with: anime.title.romaji, imageUrl: imageUrl)
            return cell
        } else if collectionView == self.airingCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AiringAnimeCell", for: indexPath) as! AiringAnimeCell
            let anime = airingAnime[indexPath.item]
            let imageUrl = URL(string: anime.coverImage.large)
            cell.configure(
                with: anime.title.romaji,
                imageUrl: imageUrl,
                episodes: anime.episodes,
                description: anime.description,
                airingAt: anime.airingAt
            )
            return cell
        }
        fatalError("Unexpected collection view")
    }
}

extension WatchNextViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var selectedAnime: Anime?
        
        if collectionView == self.collectionView {
            selectedAnime = trendingAnime[indexPath.item]
        } else if collectionView == self.seasonalCollectionView {
            selectedAnime = seasonalAnime[indexPath.item]
        } else if collectionView == self.airingCollectionView {
            selectedAnime = airingAnime[indexPath.item]
        }
        
        guard let anime = selectedAnime else { return }
        
        let storyboard = UIStoryboard(name: "AnilistAnimeInformation", bundle: nil)
        if let animeDetailVC = storyboard.instantiateViewController(withIdentifier: "AnimeInformation") as? AnimeInformation {
            animeDetailVC.animeID = anime.id
            navigationController?.pushViewController(animeDetailVC, animated: true)
        }
    }
}

struct Anime {
    let id: Int
    let title: Title
    let coverImage: CoverImage
    let episodes: Int?
    let description: String?
    let airingAt: Int?
    var mediaRelations: [MediaRelation] = []
    var characters: [Character] = []
}

struct MediaRelation {
    let node: MediaNode
    
    struct MediaNode {
        let id: Int
        let title: Title
    }
}

struct Character {
    let node: CharacterNode
    let role: String
    
    struct CharacterNode {
        let id: Int
        let name: Name
        
        struct Name {
            let full: String
        }
    }
}

struct Title {
    let romaji: String
    let english: String?
    let native: String?
}

struct CoverImage {
    let large: String
}
