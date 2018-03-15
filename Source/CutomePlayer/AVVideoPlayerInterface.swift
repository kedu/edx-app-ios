//
//  AVVideoPlayerInterface.swift
//  edX
//
//  Created by Salman on 14/03/2018.
//  Copyright © 2018 edX. All rights reserved.
//

import UIKit


protocol VideoPlayerInterfaceDelegate {
    func transcriptLoaded(transcripts: [SubTitle])
}

class AVVideoPlayerInterface: UIViewController, VideoPlayerControlsDelegate {
    
    let playerController = AVVideoPlayer()
    var delegate : VideoPlayerInterfaceDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        playerController.view.backgroundColor = UIColor.black
        createPlayer()
        addSubViews()
    }
    
    func createPlayer() {
        let playerControls = AVVideoPlayerControls(with: playerController)
        playerControls.delegate = self
        playerController.setControls(controls: playerControls)
    }
    
    func addSubViews() {
        addChildViewController(playerController)
        view.addSubview(playerController.view)
        setConstraints()
    }
    func setConstraints()  {
        playerController.view.snp_makeConstraints { make in
            make.edges.equalTo(view)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func playVideo(video : OEXHelperVideoDownload) {
        
        playerController.playerControls?.video = video
        
        if let videoURL = video.summary?.videoURL {
            
            var url : URL? = URL(string:videoURL)
            let fileManager = FileManager.default
            let path = "\(video.filePath).mp4"
            let fileExists : Bool = fileManager.fileExists(atPath: path)
            if fileExists {
                url = URL(fileURLWithPath: path)
            }
            if video.downloadState == .complete && !fileExists {
                return
            }
//            [self updateLastPlayedVideoWith:video];
            playerController.contentURL = url
            playerController.play()
        }
    }
 
    func transcriptLoaded(transcripts: [SubTitle]) {
        self.delegate?.transcriptLoaded(transcripts: transcripts)
    }
    
}
