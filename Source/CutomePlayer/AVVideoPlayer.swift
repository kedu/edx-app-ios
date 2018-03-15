//
//  AVVideoPlayer.swift
//  edX
//
//  Created by Salman on 05/03/2018.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit
import AVKit

private var playbackLikelyToKeepUpContext = 0
@objc class AVVideoPlayer: AVPlayerViewController {

    var contentURL : URL?
    let videoPlayer = AVPlayer()
    var avPlayerLayer: AVPlayerLayer!
    var playerControls: AVVideoPlayerControls?
    let loadingIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    //var lastElapsedTime: Float64 = 0.0
    var lastElapsedTime: TimeInterval = 0
    var interfaceDelegate : VideoPlayerInterfaceDelegate?
    
    var rate: Float {
        get {
            return videoPlayer.rate
        }
        set {
            videoPlayer.rate = newValue
        }
    }
    
    var duration: CMTime {
        return videoPlayer.currentItem?.duration ?? CMTime()
    }
    
    var currentTime: TimeInterval {
        return videoPlayer.currentItem?.currentTime().seconds ?? 0
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        player = videoPlayer
        showsPlaybackControls = false
        view.layer.backgroundColor = UIColor.black.cgColor

        
        avPlayerLayer = AVPlayerLayer(player: videoPlayer)
        view.layer.insertSublayer(avPlayerLayer, at: 0)
        loadingIndicatorView.hidesWhenStopped = true
        videoPlayer.addObserver(self, forKeyPath: "currentItem.playbackLikelyToKeepUp",
                                options: .new, context: &playbackLikelyToKeepUpContext)
        
        //NotificationCenter.default.addObserver(self, selector: #selector(OEXVideoPlayerInterface.orientationChanged(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)

    }

    /*
    @objc func orientationChanged (notification: NSNotification) {
        adjustViews(for:UIApplication.shared.statusBarOrientation)
    }
    
    func adjustViews(for orientation: UIInterfaceOrientation) {
        if (orientation == .portrait || orientation == .portraitUpsideDown)
        {
            
//            if(orientation != orientations) {
//                println("Portrait")
//                //Do Rotation stuff here
//                orientations = orientation
//            }
        }
        else if (orientation == .landscapeLeft || orientation == .landscapeRight)
        {
//            if(orientation != orientations) {
//                println("Landscape")
//                //Do Rotation stuff here
//                orientations = orientation
//            }
        }
    }
*/
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &playbackLikelyToKeepUpContext, let currentItem = videoPlayer.currentItem {
            if currentItem.isPlaybackLikelyToKeepUp {
                loadingIndicatorView.stopAnimating()
            } else {
                loadingIndicatorView.startAnimating()
            }
        }
    }
    
    func setControls(controls: AVVideoPlayerControls) {
        if let contentView = contentOverlayView {
            playerControls = controls
            contentView.addSubview(controls)
            contentView.addSubview(loadingIndicatorView)
            setControlsConstraints()
        }
    }
    
    private func setControlsConstraints() {
        if let contentView = contentOverlayView {
            playerControls?.snp_makeConstraints(closure: { make in
                make.edges.equalTo(contentView)
            })
            loadingIndicatorView.snp_makeConstraints() { make in
                make.center.equalTo(contentView.center)
                make.height.equalTo(50)
                make.width.equalTo(50)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }

    func play() {
        if let url = contentURL {
            let playerItem = AVPlayerItem(url: url)
            videoPlayer.replaceCurrentItem(with: playerItem)
        }
         videoPlayer.play()
    }
    
    func resume() {
        print("Played \(self.lastElapsedTime)")
        resume(at: lastElapsedTime)
    }
    
    func resume(at time: TimeInterval) {
        videoPlayer.currentItem?.seek(to: CMTimeMakeWithSeconds(time, 100), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) { [weak self]
            (completed: Bool) -> Void in
            self?.videoPlayer.play()
        }
    }
    
    func pause() {
            self.videoPlayer.pause()
            self.lastElapsedTime = self.currentTime
            print("pause \(self.lastElapsedTime)")
    }
    
    func stop() {
        videoPlayer.replaceCurrentItem(with: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        stop()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
    }
}
