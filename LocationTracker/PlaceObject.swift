//
//  PlaceObject.swift
//  LocationTracker
//
//  Created by Mark Watson on 4/6/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Realm
import RealmSwift

class PlaceObject: Object {
    
    dynamic var docId: String?
    dynamic var geometry: Geometry?
    dynamic var name: String?
    dynamic var timestamp: Double = 0
    
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: AnyObject, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    init?(docId: String?, latitude: Double, longitude: Double, name: String, timestamp: NSDate) {
        self.docId = docId
        self.geometry = Geometry(latitude: latitude, longitude: longitude)
        self.name = name
        self.timestamp = (NSDate().timeIntervalSince1970 * 1000)
        //
        super.init()
    }
    
    convenience init?(aDict dict:[String:AnyObject]) {
        if let body = dict["doc"] as? [String:AnyObject] {
            var geometry: [String:AnyObject]? = body["geometry"] as? [String:AnyObject]
            var coordinates: [Double]? = geometry!["coordinates"] as? [Double]
            let latitude: Double = coordinates![1]
            let longitude: Double = coordinates![0]
            let name: String? = body["name"] as? String
            let timestamp: Double? = body["created_at"] as? Double
            self.init(docId: body["_id"] as? String, latitude: latitude, longitude: longitude, name: name!, timestamp: NSDate(timeIntervalSince1970: Double(timestamp!)/1000.0))
        }
        else {
            print("Error initializing place from dictionary: \(dict)")
            return nil
        }
    }
}
