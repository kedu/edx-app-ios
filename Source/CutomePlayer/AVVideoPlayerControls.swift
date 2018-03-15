//
//  AVVideoPlayerControls.swift
//  edX
//
//  Created by Salman on 06/03/2018.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit

enum AVVideoPlayerControlsState {
    case AVVideoPlayerControlsStateIdle,  //Controls are not doing anything
    AVVideoPlayerControlsStateLoading, //Controls are waiting for movie to finish loading
    AVVideoPlayerControlsStateReady //Controls are ready to play and/or playing
}

enum AVVideoPlayerControlsStyle {
    case AVVideoPlayerControlsStyleEmbedded, //Controls will appear in a bottom bar
    AVVideoPlayerControlsStyleFullscreen, //Controls will appear in a top bar and bottom bar
    AVVideoPlayerControlsStyleDefault, //Controls will appear as CLVideoPlayerControlsStyleFullscreen when in fullscreen and CLVideoPlayerControlsStyleEmbedded at all other times
    AVVideoPlayerControlsStyleNone //Controls will not appear
}

protocol VideoPlayerControlsDelegate {
    func transcriptLoaded(transcripts: [SubTitle])
}

class AVVideoPlayerControls: UIView, CLButtonDelegate, VideoPlayerSettingsDelegate {
    
    var video : OEXHelperVideoDownload? {
        didSet {
            initializeSubtitleWithTimer()
        }
    }
    var playerSettings : OEXVideoPlayerSettings = OEXVideoPlayerSettings()
    var playerRateBeforeSeek: Float = 0
    var isControlsHidden: Bool = true
    let subTitleParser = SubTitleParser()
    var delegate : VideoPlayerControlsDelegate?
    
    lazy var subTitleLabel : UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor(red: 31.0/255.0, green: 33.0/255.0, blue: 36.0/255.0, alpha: 0.4)
        label.textColor = UIColor.white
        label.numberOfLines = 0
        label.layer.cornerRadius = 5
        label.layer.rasterizationScale = UIScreen.main.scale
        label.textAlignment = NSTextAlignment.center
        label.layer.shouldRasterize = true
        return label
    }()
    
    lazy var topBar: UIView = {
        let view = UIView()
        view.backgroundColor = self.barColor
        view.alpha = 0
        return view
    }()
    
    lazy var tapButton: UIButton = {
        let button = UIButton()
        button.oex_addAction({ [weak self] _ in
            self?.contentTapped()
            }, for: .touchUpInside)
        return button
    }()
    
    lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = self.barColor
        return view
    }()
    
    lazy var rewindButton: CLButton = {
        let button = CLButton()
        button.setImage(UIImage.RewindIcon(), for: .normal)
        button.tintColor = .white
        button.delegate = self
        button.addTarget(self, action: #selector(seekBackwardPressed), for: .touchUpInside)
        return button
    }()
    
    lazy var durationSlider: OEXCustomSlider = {
        let slider = OEXCustomSlider()
        slider.isContinuous = true
        slider.setThumbImage(UIImage(named: "ic_seek_thumb"), for: .normal)
        slider.setMinimumTrackImage(UIImage(named: "ic_progressbar.png"), for: .normal)
        slider.secondaryTrackColor = UIColor(red: 76.0/255.0, green: 135.0/255.0, blue: 130.0/255.0, alpha: 0.9)
        slider.addTarget(self, action: #selector(durationSliderValueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(durationSliderTouchBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(durationSliderTouchEnded), for: .touchUpInside)
        slider.addTarget(self, action: #selector(durationSliderTouchEnded), for: .touchUpOutside)
        
        return slider
    }()
    
    lazy var btnSettings: CLButton = {
        let button = CLButton()
        button.setImage(UIImage.SettingsIcon(), for: .normal)
        button.tintColor = .white
        button.delegate = self
        button.addTarget(self, action: #selector(settingsButtonClicked), for: .touchUpInside)
        return button
    }()
    
    lazy var tableSettings: UITableView = {
        let tableView = self.playerSettings.optionsTable
        tableView.isHidden = true
        self.playerSettings.delegate = self
        return tableView
    }()
    
    lazy var playPauseButton : AccessibilityCLButton = {
        let button = AccessibilityCLButton()
        button.setAttributedTitle(title: UIImage.PauseTitle(), forState: .normal, animated: true)
        button.setAttributedTitle(title: UIImage.PlayTitle(), forState: .selected, animated: true)
        //        button.isSelected = _moviePlayer.playbackState == MPMoviePlaybackStatePlaying ? NO: YES
        button.addTarget(self, action: #selector(playPausePressed), for: .touchUpInside)
        button.delegate = self;
        return button
    }()
    
    lazy var btnNext: CLButton = {
        let button = CLButton()
        button.setImage(UIImage(named: "ic_next"), for: .normal)
        button.setImage(UIImage(named: "ic_next_press"), for: .highlighted)
        button.addTarget(self, action: #selector(nextButtonClicked), for: .touchUpInside)
        button.delegate = self;
        return button
    }()
    
    lazy var btnPrevious: CLButton = {
        let button = CLButton()
        button.setImage(UIImage(named: "ic_previous"), for: .normal)
        button.setImage(UIImage(named: "ic_previous_press"), for: .highlighted)
        button.addTarget(self, action: #selector(previousButtonClicked), for: .touchUpInside)
        button.delegate = self;
        return button
    }()
    
    lazy var fullScreenButton: CLButton = {
        let button = CLButton()
        button.setImage(UIImage.ExpandIcon(), for: .normal)
        button.tintColor = .white
        button.delegate = self
        button.addTarget(self, action: #selector(fullscreenPressed), for: .touchUpInside)
        return button
    }()
    lazy var dismissOptionOverlayButton: CLButton = CLButton()
    lazy var timeElapsedLabel: UILabel = UILabel()
    lazy var timeRemainingLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .lightText
        label.textAlignment = .center
        label.text = Strings.videoPlayerDefaultRemainingTime
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowRadius = 1
        label.layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        label.layer.shadowOpacity = 0.8
        label.font = OEXStyles.shared().semiBoldSansSerif(ofSize: 12.0)
        return label
    }()
    lazy var videoTitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.font = OEXStyles.shared().semiBoldSansSerif(ofSize: 16.0)
        label.textAlignment = .left
        label.textColor = .white
        label.text = Strings.untitled
        //        if(_moviePlayer.videoTitle == nil || [_videoTitleLabel.text isEqualToString:@""]) {
        //            _videoTitleLabel.text = [Strings untitled];
        //            _moviePlayer.videoTitle = [Strings untitled];
        //        }
        //        else {
        //            _videoTitleLabel.text = self.moviePlayer.videoTitle;
        //        }
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowRadius = 1
        label.layer.shadowOffset = CGSize(width: 1.0, height: 1.0)
        label.layer.shadowOpacity = 0.8
        return label
    }()
    lazy var seekForwardButton: UILabel = UILabel()
    let videoPlayerController: AVVideoPlayer
    var timeObserver : AnyObject?
    var seeking: Bool = false
    var lastElapsedTime: Float64 = 0.0
    var dataInterface = OEXInterface.shared()
    private var barColor: UIColor {
        return UIColor.black.withAlphaComponent(0.7)
    }
    
    init(with player: AVVideoPlayer) {
        videoPlayerController = player
        super.init(frame: CGRect.zero)
        seeking = false
        playerSettings.delegate = self
        backgroundColor = .clear
        addSubviews()
        hideAndShowControls(isHidden: isControlsHidden)
        addTimeObserver()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func initializeSubtitleWithTimer() {
        
        var captionURL : String = ""
        if let ccSelectedLanguage = OEXInterface.getCCSelectedLanguage(), let url = video?.summary?.transcripts?[ccSelectedLanguage] as? String, ccSelectedLanguage != "", url != ""{
            captionURL = url
            
            //self.subtitleActivated = YES;
            //[self setCaptionWithLanguage:ccSelectedLanguage];
            setCaption(language: ccSelectedLanguage)
            
        } else if let url = video?.summary?.transcripts?.values.first as? String  {
            captionURL = url
            //self.subtitleActivated = false;
            //[self activateSubTitles:captionURL];
            activateSubTitles(urlString: captionURL)
        }
        
        
        /*
         if(!self.subtitleTimer.isValid) {
         self.subtitleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
         target:self
         selector:@selector(searchAndDisplaySubtitle)
         userInfo:nil
         repeats:YES];
         [self.subtitleTimer fire];
         }
         
         // Add label
         CGFloat fontSize = 0.0;
         if(self.style == CLVideoPlayerControlsStyleFullscreen || (self.style == CLVideoPlayerControlsStyleDefault && self.moviePlayer.isFullscreen)) {
         fontSize = 18.0;        //MOB-1146
         }
         else if(self.style == CLVideoPlayerControlsStyleEmbedded || (self.style == CLVideoPlayerControlsStyleDefault && !self.moviePlayer.isFullscreen)) {
         fontSize = 12.0;
         }
         
         self.subtitleLabel.font = [[OEXStyles sharedStyles] sansSerifOfSize:fontSize];
         */
    }
    
    private func addTimeObserver() {
        let timeInterval: CMTime = CMTimeMakeWithSeconds(1.0, 10)
        timeObserver = videoPlayerController.videoPlayer.addPeriodicTimeObserver(forInterval: timeInterval, queue: DispatchQueue.main) { [weak self]
            (elapsedTime: CMTime) -> Void in
            self?.observeTime(elapsedTime: elapsedTime)
            } as AnyObject
        
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedTranscript), name: NSNotification.Name(rawValue: DL_COMPLETE), object: nil)
    }
    
    fileprivate func addSubviews() {
        addSubview(topBar)
        topBar.addSubview(videoTitleLabel)
        addSubview(bottomBar)
        bottomBar.addSubview(rewindButton)
        bottomBar.addSubview(durationSlider)
        bottomBar.addSubview(timeRemainingLabel)
        bottomBar.addSubview(btnSettings)
        bottomBar.addSubview(fullScreenButton)
        addSubview(btnNext)
        addSubview(btnPrevious)
        addSubview(tapButton)
        addSubview(playPauseButton)
        addSubview(tableSettings)
        addSubview(subTitleLabel)
        setConstraints()
    }
    
    
    
    private func observeTime(elapsedTime: CMTime) {
        let duration = CMTimeGetSeconds(videoPlayerController.duration)
        if duration.isFinite {
            let elapsedTime = CMTimeGetSeconds(elapsedTime)
            durationSlider.value = Float(elapsedTime / duration)
            updateTimeLabel(elapsedTime: elapsedTime, duration: duration)
        }
    }
    
    private func setConstraints() {
        bottomBar.snp_makeConstraints { make in
            make.leading.equalTo(self)
            make.bottom.equalTo(self)
            make.width.equalTo(self)
            make.height.equalTo(50)
        }
        
        rewindButton.snp_makeConstraints { make in
            make.leading.equalTo(self).offset(StandardVerticalMargin)
            make.height.equalTo(25.0)
            make.width.equalTo(25.0)
            make.centerY.equalTo(bottomBar.snp_centerY)
        }
        
        durationSlider.snp_makeConstraints { make in
            make.leading.equalTo(rewindButton.snp_trailing).offset(10.0)
            make.height.equalTo(34.0)
            make.centerY.equalTo(bottomBar.snp_centerY)
        }
        
        timeRemainingLabel.setContentHuggingPriority(UILayoutPriorityDefaultHigh, for: .horizontal)
        timeRemainingLabel.snp_makeConstraints { make in
            make.leading.equalTo(durationSlider.snp_trailing).offset(10.0)
            make.centerY.equalTo(bottomBar.snp_centerY)
        }
        
        btnSettings.snp_makeConstraints { make in
            make.leading.equalTo(timeRemainingLabel.snp_trailing).offset(10.0)
            make.height.equalTo(24.0)
            make.width.equalTo(24.0)
            make.centerY.equalTo(bottomBar.snp_centerY)
        }
        
        fullScreenButton.snp_makeConstraints { make in
            make.leading.equalTo(btnSettings.snp_trailing).offset(10.0)
            make.height.equalTo(20.0)
            make.width.equalTo(20.0)
            make.trailing.equalTo(self).inset(10)
            make.centerY.equalTo(bottomBar.snp_centerY)
        }
        
        tableSettings.snp_makeConstraints { make in
            make.height.equalTo(100)
            make.width.equalTo(100)
            make.bottom.equalTo(btnSettings.snp_top).offset(-10)
            make.centerX.equalTo(btnSettings.snp_centerX)
        }
        
        tapButton.snp_makeConstraints { make in
            make.leading.equalTo(self)
            make.trailing.equalTo(self)
            make.top.equalTo(self)
            make.bottom.equalTo(bottomBar.snp_top)
        }
        
        playPauseButton.snp_makeConstraints { make in
            make.center.equalTo(tapButton.center)
        }
        
        subTitleLabel.snp_makeConstraints { make in
            make.bottom.equalTo(bottomBar.snp_top).offset(16)
            make.centerX.equalTo(snp_centerX)
            make.leadingMargin.greaterThanOrEqualTo(16)
            make.trailingMargin.lessThanOrEqualTo(16)
        }
        
    }
    
    @objc private func autoHide() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(hideAndShowControls(isHidden:)), with: 1, afterDelay: 3.0)
    }
    
    @objc private func hideAndShowControls(isHidden: Bool) {
        isControlsHidden = isHidden
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            let alpha: CGFloat = isHidden ? 0 : 1
            self?.topBar.alpha = alpha
            self?.bottomBar.alpha = alpha
            self?.bottomBar.isUserInteractionEnabled = !isHidden
            self?.playPauseButton.alpha = alpha
            self?.playPauseButton.isUserInteractionEnabled = !isHidden
            self?.btnPrevious.alpha = alpha
            self?.btnNext.alpha = alpha
            self?.btnNext.isUserInteractionEnabled = !isHidden
            self?.btnPrevious.alpha = alpha
            self?.btnPrevious.isUserInteractionEnabled = !isHidden
            
            if (!isHidden) {
                self?.autoHide()
            }
            
        }) { _ in
            
        }
    }
    
    private func updateTimeLabel(elapsedTime: Float64, duration: Float64) {
        let totalTime: Float64 = CMTimeGetSeconds(videoPlayerController.duration)
        let timeRemaining: Float64 = totalTime - elapsedTime
        timeRemainingLabel.text = String(format: "%02d:%02d / %02d:%02d", ((lround(timeRemaining) / 60) % 60), lround(timeRemaining) % 60, ((lround(totalTime) / 60) % 60), lround(totalTime) % 60)
        // Apply Condition
        subTitleLabel.text = subTitleParser.getSubTitle(at: elapsedTime)
    }
    
    // MARK: Slider Handling
    @objc private func durationSliderValueChanged()  {
        let videoDuration = CMTimeGetSeconds(videoPlayerController.duration)
        let elapsedTime: Float64 = videoDuration * Float64(durationSlider.value)
        updateTimeLabel(elapsedTime: elapsedTime, duration: videoDuration)
    }
    @objc private func durationSliderTouchBegan()  {
        playerRateBeforeSeek = videoPlayerController.rate
        print("Rate: \(playerRateBeforeSeek)")
        videoPlayerController.pause()
    }
    @objc private func durationSliderTouchEnded()  {
        let videoDuration = CMTimeGetSeconds(videoPlayerController.duration)
        let elapsedTime: Float64 = videoDuration * Float64(durationSlider.value)
        updateTimeLabel(elapsedTime: elapsedTime, duration: videoDuration)
        
        videoPlayerController.videoPlayer.seek(to: CMTimeMakeWithSeconds(elapsedTime, 100)) { [weak self]
            (completed: Bool) -> Void in
            //            if self?.playerRateBeforeSeek ?? 0.0 > 0.0 {
            print("Played \(elapsedTime)")
            self?.videoPlayerController.videoPlayer.play()
            //            }
        }
    }
    
    @objc private func seekBackwardPressed() {
        let videoDuration = CMTimeGetSeconds(videoPlayerController.duration)
        let elapsedTime: Float64 = videoDuration * Float64(durationSlider.value)
        let backTime = elapsedTime > 30 ? elapsedTime - 30 : 0.0
        updateTimeLabel(elapsedTime: backTime, duration: videoDuration)
        
        videoPlayerController.videoPlayer.seek(to: CMTimeMakeWithSeconds(backTime, 100)) { [weak self]
            (completed: Bool) -> Void in
            //            if self?.playerRateBeforeSeek ?? 0.0 > 0.0 {
            print("Played \(elapsedTime)")
            self?.videoPlayerController.videoPlayer.play()
            //            }
        }
        
    }
    @objc private func playPausePressed() {
        print("playPausePressed----->>")
        playPauseButton.isSelected = !playPauseButton.isSelected
        if videoPlayerController.videoPlayer.isPlaying {
            videoPlayerController.pause()
        }
        else {
            videoPlayerController.resume()
        }
        autoHide()
    }
    
    @objc private func fullscreenPressed() {
        autoHide()
    }
    
    private func contentTapped() {
        if tableSettings.isHidden {
            hideAndShowControls(isHidden: !isControlsHidden)
        }
        else {
            tableSettings.isHidden = true
            autoHide()
        }
    }
    @objc private func nextButtonClicked() {
        autoHide()
    }
    @objc private func previousButtonClicked() {
        autoHide()
    }
    
    @objc private func settingsButtonClicked() {
        NSObject.cancelPreviousPerformRequests(withTarget:self)
        tableSettings.isHidden = !tableSettings.isHidden
    }
    
    func showSubSettings(chooser: UIAlertController) {
        let controller = UIApplication.shared.keyWindow?.rootViewController
        chooser.configurePresentationController(withSourceView: btnSettings)
        controller?.present(chooser, animated: true, completion: { [weak self] in
            self?.btnSettings.isHidden = true
        })
    }
    
    func setCaption(language: String) {
    }
    
    func setPlaybackSpeed(speed: OEXVideoSpeed) {
    }
    
    func videoInfo() -> OEXVideoSummary? {
        return video?.summary
    }
    
    func activateSubTitles(urlString: String) {
        getClosedCaptioningFile(atURL: urlString, completion: { (success, error) in
            if success{
                print(subTitleParser.subTitles)
                //show subtitles
                //if (self.subtitleActivated) {
                //   [self showSubtitles];
                //}
                self.delegate?.transcriptLoaded(transcripts: subTitleParser.subTitles)
            }
            else {
                //hide subtitles
                //[self hideSubtitles];
            }
        })
    }
    
    func downloadedTranscript(note: Notification) {
        if let task = note.userInfo?[DL_COMPLETE_N_TASK] as? URLSessionDownloadTask, let taskURL = task.response?.url {
            var captionURL: String = ""
            if let ccSelectedLanguage = OEXInterface.getCCSelectedLanguage(), let url = video?.summary?.transcripts?[ccSelectedLanguage] as? String{
                captionURL = url
            }
            else if let url = video?.summary?.transcripts?.values.first as? String  {
                captionURL = url
            }
            
            if taskURL.absoluteString == captionURL {
                activateSubTitles(urlString: captionURL)
            }
        }
    }
    
    func getClosedCaptioningFile(atURL URLString: String?, completion: SubTitleParsingCompletion ) {
        if let localFile: String = OEXFileUtility.filePath(forRequestKey: URLString) {
            var subtitleString = ""
            // File to string
            if FileManager.default.fileExists(atPath: localFile) {
                // File to string
                do {
                    let subTitle = try String(contentsOfFile: localFile, encoding: .utf8)
                    subtitleString = subTitle.replacingOccurrences(of: "\r", with:"\n")
                    subTitleParser.parse(subTitlesString: subtitleString, completion: { (success, error) in
                        completion(success, error)
                    })
                }
                catch let error {
                    completion(false, error)
                    return
                }
                
            }
            else {
                dataInterface.download(withRequest: URLString, forceUpdate: false)
            }
        }
    }
    
    
    /*
     
     
     #pragma mark Closed Captions
     
     
     - (void) setCaptionWithLanguage:(NSString*)language{
     [self hideTables];
     [OEXInterface setCCSelectedLanguage:language];
     
     if ([language isEqualToString:@""]) {
     
     // Analytics HIDE TRANSCRIPT
     if(self.video.summary.videoID) {
     [[OEXAnalytics sharedAnalytics] trackHideTranscript:self.video.summary.videoID
     CurrentTime:[self getMoviePlayerCurrentTime]
     CourseID:self.video.course_id
     UnitURL:self.video.summary.unitURL];
     }
     _dataInterface.selectedCCIndex = -1;
     self.subtitlesParts = nil;
     [self hideSubtitles];
     return;
     }
     
     NSString* captionURL = self.video.summary.transcripts[language];
     if (captionURL) {
     self.subtitleActivated = YES;
     [self activateSubTitles:captionURL];
     // Set the language to persist
     [OEXInterface setCCSelectedLanguage:language];
     
     if(self.video.summary.videoID) {
     [[OEXAnalytics sharedAnalytics] trackTranscriptLanguage: self.video.summary.videoID
     CurrentTime: [self getMoviePlayerCurrentTime]
     Language: language
     CourseID: self.video.course_id
     UnitURL: self.video.summary.unitURL];
     }
     }
     }
     */
    
    
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
