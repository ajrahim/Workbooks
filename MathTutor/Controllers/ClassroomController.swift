//
//  ClassroomController.swift
//  MathTutor
//
//  Created by AJ Rahim on 8/18/20.
//  Copyright © 2020 AJ Rahim. All rights reserved.
//

import Foundation
import Firebase
import SwiftyJSON

class ClassroomController : UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    var Classrooms : [QueryDocumentSnapshot] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.register(UINib(nibName: "ClassroomCell", bundle: nil), forCellWithReuseIdentifier: "ClassroomCell")
        self.collectionView.reloadData()
        
        self.GetClassrooms()
    } 
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        self.tabBarController?.tabBar.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool){
        super.viewDidAppear(animated)
        
        self.GetClassrooms()
    }
    
    func GetClassrooms(){

        let db = Firestore.firestore()
        db.collection("classrooms").getDocuments() { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                
                self.Classrooms = snapshot!.documents
                self.collectionView?.reloadData()
                
            }
        }
    }
    
    @IBAction func ActionCreate(_ sender: Any) {


        let db = Firestore.firestore()
        var ref: DocumentReference? = nil
        ref = db.collection("classrooms").addDocument(data: [
            "student" : false,
            "teacher" : false,
            "progress" : [false, false, false, false, false, false, false, false, false, false]
        ]) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Document added with ID: \(ref!.documentID)")
                
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-1").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-2").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-3").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-4").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-5").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-6").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-7").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-8").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-9").setData(["tutor" : "", "student" : ""])
                db.collection("classrooms/\(ref!.documentID)/drawings").document("workbook-10").setData(["tutor" : "", "student" : ""])
                
                self.collectionView.reloadData()
            }
        }

        
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 230, height: 160)
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.Classrooms.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let json = JSON(Classrooms[indexPath.row].data())
        let cell: ClassroomCell = collectionView.dequeueReusableCell(withReuseIdentifier: "ClassroomCell", for: indexPath as IndexPath) as! ClassroomCell
        cell.ClassroomID.text = Classrooms[indexPath.row].documentID
        var ProgressCurrent = 0
        for Completed in json["progress"].arrayValue {
            print(Completed)
            if(Completed.boolValue){
                ProgressCurrent += 1
            }
        }
        
        cell.ConstraintProgress.constant = (cell.ProgressWrapper.frame.width * (CGFloat(ProgressCurrent) / 10))
        print(cell.ProgressWrapper.frame.width)
        print(ProgressCurrent)
        print(cell.ConstraintProgress.constant)
        cell.ProgressWrapper.layoutSubviews()
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let alert = UIAlertController(title: "Role", message: "Are you a student or tutor?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Student", style: .default, handler: { [weak alert] (_) in
            let Controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ViewController") as! ViewController
            Controller.id = self.Classrooms[indexPath.row].documentID
            Controller.json = JSON(self.Classrooms[indexPath.row].data())
            Controller.student = true
            self.navigationController?.pushViewController(Controller, animated: true)
        }))
        
        alert.addAction(UIAlertAction(title: "Tutor", style: .default, handler: { [weak alert] (_) in
            let Controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ViewController") as! ViewController
            Controller.id = self.Classrooms[indexPath.row].documentID
            Controller.json = JSON(self.Classrooms[indexPath.row].data())
            Controller.student = false
            self.navigationController?.pushViewController(Controller, animated: true)
        }))

        
        self.present(alert, animated: true, completion: nil)
    }
    
}
