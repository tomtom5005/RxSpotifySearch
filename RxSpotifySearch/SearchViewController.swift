//
//  ViewController.swift
//  RxSpotifySearch
//
//  Created by Adam Borek on 04/11/2016.
//  Copyright (c) 2016 Adam Borek. All rights reserved.
//

import UIKit
import Foundation
import SwiftyJSON
import RxSwift
import RxCocoa

class SearchViewController: UITableViewController {
    fileprivate enum Constants {
        static let minimumSearchLength = 3
    }
    @IBOutlet weak var searchBar: UISearchBar!
    
//    private lazy var isRefreshing: Observable<Bool> = {
//        let refreshControl = self.refreshControl
//        return refreshControl?.rx.controlEvent(.valueChanged)
//            .map { return refreshControl?.isRefreshing ?? false }
//            ?? .just(false)
//    }()
    
//    private lazy var searchText: Observable<String> = {
//        return self.searchBar.rx.text.orEmpty.asObservable()
//            .skip(1)
//    }()
    
//    private lazy var query: Observable<String> = {
//        return self.searchText
//            .debounce(0.3, scheduler: MainScheduler.instance)
//            .filter(self.filterQuery(containsLessCharactersThan: Constants.minimumSearchLength))
//    }()
    
//    private var tracksFromSpotify: Observable<[TrackRenderable]> {
//        let refreshLastQueryOnPullToRefresh = isRefreshing.filter { $0 == true }
//            .withLatestFrom(query)
//
//        return Observable.of(query, refreshLastQueryOnPullToRefresh).merge()
//            .startWith("Let it go - frozen")
//            .flatMapLatest { [spotifyClient] query in
//                return spotifyClient.rx.search(query: query)
//                    .map { return $0.map(TrackRenderable.init) }
//        }
//    }
    
//    var tracks: Observable<[TrackRenderable]> {
//        return Observable.of(tracksFromSpotify.do(onNext: { [refreshControl] _ in refreshControl?.endRefreshing() }),
//                             clearPreviousTracksOnTextChanged).merge()
//    }
    
//    private var clearPreviousTracksOnTextChanged: Observable<[TrackRenderable]> {
//        return searchText
//            .filter(self.filterQuery(containsLessCharactersThan: Constants.minimumSearchLength))
//            .map { _ in
//                return [TrackRenderable]()
//        }
//    }
    
    
    private let disposeBag = DisposeBag()
    
    let spotifyClient = SpotifyClient()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = searchBar
        setupTableView()

        let didPullToRefresh: Observable<Void> = (refreshControl?.rx.controlEvent(.valueChanged)
            .map { [refreshControl] in
                return refreshControl?.isRefreshing
            }.filter { $0 == true }
            .map { _ in return () })!
        
        let searchText = searchBar.rx.text.orEmpty.asObservable().skip(1)
        
        let query = searchText
            .debounce(0.3, scheduler: MainScheduler.instance)
            .startWith("Let it go - frozen")
        
        let refreshWithLastQuery = didPullToRefresh.withLatestFrom(searchText)
        
        let tracksFromSpotify = Observable.of(query, refreshWithLastQuery).merge()
            .flatMapLatest { [spotifyClient] query in
                return spotifyClient.rx.search(query: query)
            }
            .debug("flatmapLatest")
            .map { tracks in
                return tracks.map(TrackRenderable.init)
            }.do(onNext: { _ in self.refreshControl?.endRefreshing()})
        
        let clearTracksOnQueryChanged = searchText
            .filter { string in
                string.count < Constants.minimumSearchLength }
            .map { _ in return [TrackRenderable]() }
        
        let tracks = Observable.of(tracksFromSpotify, clearTracksOnQueryChanged).merge()
        
        tracks.bindTo(tableView.rx.items(cellIdentifier: "TrackCell", cellType: TrackCell.self)) { index, track, cell in
            cell.render(trackRenderable: track)
            }.addDisposableTo(disposeBag)
    }
    
    private func setupTableView() {
        tableView.delegate = nil
        tableView.rx.setDelegate(self)
            .addDisposableTo(disposeBag)
        tableView.dataSource = nil
        tableView.rx.itemSelected.subscribe(onNext: { [tableView] index in
            tableView?.deselectRow(at: index, animated: false)
        }).addDisposableTo(disposeBag)
        let control = UIRefreshControl()
        tableView.addSubview(control)
        self.refreshControl = UIRefreshControl()
    }
    
    private func setupCancelSearchButton() {
        let shouldShowCancelButton = Observable.of(
            searchBar.rx.textDidBeginEditing.map { return true },
            searchBar.rx.textDidEndEditing.map { return false } )
            .merge()
        
        shouldShowCancelButton.subscribe(onNext: { [searchBar] shouldShow in
            searchBar?.showsCancelButton = shouldShow
        }).addDisposableTo(disposeBag)
        
        searchBar.rx.cancelButtonClicked.subscribe(onNext: { [searchBar] in
            searchBar?.resignFirstResponder()
        }).addDisposableTo(disposeBag)
    }
    
//    //Returns the predicate function for the rx filter
//    private func filterQuery(containsLessCharactersThan minimumCharacters: Int) -> (String) -> Bool {
//        return { string in
//            return string.characters.count >= minimumCharacters
//        }
//    }
}

