//
//  ViewController.swift
//  MathTutor
//
//  Created by AJ Rahim on 8/14/20.
//  Copyright © 2020 AJ Rahim. All rights reserved.
//

import UIKit
import AgoraRtcKit
import Drawsana
import Firebase
import SwiftyJSON

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let penTool = PenTool()


    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var drawsanaView: DrawsanaView!
    @IBOutlet weak var drawsanaTutor: DrawsanaView!
    @IBOutlet weak var localVideo: UIView!
    @IBOutlet weak var remoteVideo: UIView!
    @IBOutlet weak var remoteVideoMutedIndicator: UIImageView!
    @IBOutlet weak var localVideoMutedIndicator: UIView!
    @IBOutlet weak var ImageEquation: UIImageView!
    
    
    var agoraKit: AgoraRtcEngineKit!
    
    public var id : String!
    public var json : JSON!
    public var student : Bool = true
    var listener : ListenerRegistration!
    
    var workbookindex : Int = 1

    
    var isRemoteVideoRender: Bool = true {
        didSet {
            remoteVideoMutedIndicator.isHidden = isRemoteVideoRender
            remoteVideo.isHidden = !isRemoteVideoRender
        }
    }
    
    var isLocalVideoRender: Bool = false {
        didSet {
            localVideoMutedIndicator.isHidden = isLocalVideoRender
        }
    }
    
    var isStartCalling: Bool = true {
        didSet {
            if isStartCalling {
//                    micButton.isSelected = false
            }
//                micButton.isHidden = !isStartCalling
//                cameraButton.isHidden = !isStartCalling
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.tableView.register(UINib(nibName: "WorkbookCell", bundle: nil), forCellReuseIdentifier: "WorkbookCell")
        
        drawsanaView.delegate = self
        drawsanaView.set(tool: penTool)
        drawsanaView.userSettings.strokeWidth = 5
        drawsanaView.userSettings.strokeColor = .black
        drawsanaView.userSettings.fillColor = .black
        
        drawsanaTutor.delegate = self
        drawsanaTutor.set(tool: penTool)
        drawsanaTutor.userSettings.strokeWidth = 5
        drawsanaTutor.userSettings.strokeColor = .red
        drawsanaTutor.userSettings.fillColor = .red
        
        if(student){
            drawsanaTutor.isUserInteractionEnabled = false
        }else{
            drawsanaView.isUserInteractionEnabled = false
        }
        
        
        load();
        
        initializeAgoraEngine()
        setupVideo()
        setupLocalVideo()
        joinChannel()
        
        
        let db = Firestore.firestore()
        db.collection("classrooms").document(self.id).addSnapshotListener { documentSnapshot, error in
          guard let document = documentSnapshot else {
            print("Error fetching document: \(error!)")
            return
          }
          guard let data = document.data() else {
            print("Document data was empty.")
            return
          }
            let dataDescription = JSON(data)
            self.json["progress"] = JSON(dataDescription["progress"].arrayValue)
            self.tableView.reloadData()
        }
        
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "Graphy2x")!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        leaveChannel()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        
    }

    func save() {
        
        let db = Firestore.firestore()
        
        if(student){
            
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try! jsonEncoder.encode(drawsanaView.drawing)
            
            db.collection("classrooms/\(self.id!)/drawings").document("workbook-\(self.workbookindex)").updateData([
                "student": String(data: jsonData, encoding: .utf8)
            ]) { err in
                if let err = err {
                    print("Error updating document: \(err)")
                } else {
                    print("Done!")
                }
            }
        }else{
            
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try! jsonEncoder.encode(drawsanaTutor.drawing)
            
            db.collection("classrooms/\(self.id!)/drawings").document("workbook-\(self.workbookindex)").updateData([
                "tutor": String(data: jsonData, encoding: .utf8)
            ]) { err in
                if let err = err {
                    print("Error updating document: \(err)")
                } else {
                    print("Done!")
                }
            }
        }
        
    }
    
    func load() {
        
        for shape in drawsanaView.drawing.shapes {
            drawsanaView.drawing.remove(shape: shape)
        }
        for shape in drawsanaTutor.drawing.shapes {
            drawsanaTutor.drawing.remove(shape: shape)
        }
        
        
        
        let db = Firestore.firestore()
        let docRef = db.collection("classrooms").document(self.id).collection("drawings").document("workbook-\(self.workbookindex)")

        if(listener != nil){
            listener.remove()
        }

        listener = docRef.addSnapshotListener { documentSnapshot, error in
          guard let document = documentSnapshot else {
            print("Error fetching document: \(error!)")
            return
          }
          guard let data = document.data() else {
            print("Document data was empty.")
            return
          }
          print("Current data: \(data)")

            let dataDescription = JSON(data)

            do{
                let jsonDecoder = JSONDecoder()
                let drawing = try jsonDecoder.decode(Drawing.self, from: dataDescription["student"].stringValue.data(using: .utf8)!)
                let drawingTutor = try jsonDecoder.decode(Drawing.self, from: dataDescription["tutor"].stringValue.data(using: .utf8)!)
                self.drawsanaView.drawing = drawing
                self.drawsanaTutor.drawing = drawingTutor
                
                
            }catch{
                print("err")
            }
        }
        
        
        
    }
    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: "1385344415fc4e948f4965fa1fbf5f32", delegate: self)
    }

    func setupVideo() {
        agoraKit.enableVideo()
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360, frameRate: .fps15, bitrate: AgoraVideoBitrateStandard, orientationMode: .adaptative))
    }
    
    func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = localVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
    }
    
    func joinChannel() {
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        agoraKit.joinChannel(byToken: nil, channelId: "channel-" + self.id, info: nil, uid: 0) { [unowned self] (channel, uid, elapsed) -> Void in
            self.isLocalVideoRender = true
        }
        agoraKit.muteLocalAudioStream(true)
        isStartCalling = true
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func leaveChannel() {
        agoraKit.leaveChannel(nil)
        isRemoteVideoRender = false
        isLocalVideoRender = false
        isStartCalling = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    @IBAction func didClickHangUpButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        if sender.isSelected {
            leaveChannel()
        } else {
            joinChannel()
        }
    }
    
    @IBAction func ActionAnswer(_ sender: Any) {
        let alert = UIAlertController(title: "Answer", message: "\(Problems[self.workbookindex - 1][0]) + \(Problems[self.workbookindex - 1][1])", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.keyboardType = UIKeyboardType.numberPad
            textField.placeholder = "Answer"
        }

        alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { [weak alert] (_) in
            guard let textField = alert?.textFields?[0], let userText = textField.text else { return }
            
            if(Int(userText) == (Problems[self.workbookindex - 1][0] + Problems[self.workbookindex - 1][1])){
                
                self.json["progress"][self.workbookindex - 1] = JSON(true)
                self.tableView.reloadData()
                
                let db = Firestore.firestore()
                
                db.collection("classrooms").document(self.id).updateData([
                    "progress": [
                        self.json["progress"][0].boolValue,
                        self.json["progress"][1].boolValue,
                        self.json["progress"][2].boolValue,
                        self.json["progress"][3].boolValue,
                        self.json["progress"][4].boolValue,
                        self.json["progress"][5].boolValue,
                        self.json["progress"][6].boolValue,
                        self.json["progress"][7].boolValue,
                        self.json["progress"][8].boolValue,
                        self.json["progress"][9].boolValue,
                        self.json["progress"][10].boolValue
                    ]
                ]) { err in
                    if let err = err {
                        print("Error updating document: \(err)")
                    } else {
                        let AlertAnswer = UIAlertController(title: "Correct", message: "Great job you've successfully completed problem #\(self.workbookindex).", preferredStyle: .alert)
                        AlertAnswer.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                        self.present(AlertAnswer, animated: true, completion: nil)
                    }
                }
                
            }else{
                let AlertAnswer = UIAlertController(title: "Oops", message: "\(userText) wasn't the right answer please try again.", preferredStyle: .alert)
                AlertAnswer.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                self.present(AlertAnswer, animated: true, completion: nil)
            }
            
        }))

        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func ActionClear(_ sender: Any) {
        
        if(student){
            for shape in drawsanaView.drawing.shapes {
                drawsanaView.drawing.remove(shape: shape)
            }
        }else{
            for shape in drawsanaTutor.drawing.shapes {
                drawsanaTutor.drawing.remove(shape: shape)
            }
        }
        
        self.save()
    }
    
    @IBAction func ActionMute(_ sender: Any) {
//        sender.isSelected.toggle()
//        agoraKit.muteLocalAudioStream(sender.isSelected)
    }
    
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Problems.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: WorkbookCell = tableView.dequeueReusableCell(withIdentifier: "WorkbookCell", for: indexPath) as! WorkbookCell
        cell.WorkbookName.text = "Problem " + String(indexPath.row + 1)
        if(self.json["progress"][indexPath.row].boolValue){
            cell.IconProgress.image = UIImage(named: "IconCheckmark")
            cell.Background.backgroundColor = UIColor(named: "Green")
        }else{
            cell.IconProgress.image = UIImage(named: "IconCircle")
            cell.Background.backgroundColor = UIColor(named: "Blue")
        }
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.workbookindex = indexPath.row + 1
        self.ImageEquation.image = UIImage(named: "Math-Addition-\(self.workbookindex)")
        self.load()
    }
    
}

extension ViewController: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid:UInt, size:CGSize, elapsed:Int) {
        isRemoteVideoRender = true
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = remoteVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupRemoteVideo(videoCanvas)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid:UInt, reason:AgoraUserOfflineReason) {
        isRemoteVideoRender = false
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted:Bool, byUid:UInt) {
        isRemoteVideoRender = !muted
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
    }


}


extension ViewController: DrawsanaViewDelegate {
  
  func drawsanaView(_ drawsanaView: DrawsanaView, didSwitchTo tool: DrawingTool) {

}

  func drawsanaView(_ drawsanaView: DrawsanaView, didChangeStrokeColor strokeColor: UIColor?) {
    
  }

  func drawsanaView(_ drawsanaView: DrawsanaView, didChangeFillColor fillColor: UIColor?) {
    
  }

  func drawsanaView(_ drawsanaView: DrawsanaView, didChangeStrokeWidth strokeWidth: CGFloat) {
    
  }

  func drawsanaView(_ drawsanaView: DrawsanaView, didChangeFontName fontName: String) {
  }

  func drawsanaView(_ drawsanaView: DrawsanaView, didChangeFontSize fontSize: CGFloat) {
  }

  func drawsanaView(_ drawsanaView: DrawsanaView, didStartDragWith tool: DrawingTool) {
  }

  func drawsanaView(_ drawsanaView: DrawsanaView, didEndDragWith tool: DrawingTool) {
    self.save()
  }
}
