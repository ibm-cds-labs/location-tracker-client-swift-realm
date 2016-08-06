//
//  LocationObjectument.swift
//  LocationTracker
//
//  Created by Mark Watson on 4/4/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Realm
import RealmSwift

class LocationObject: Object {

    dynamic var docId: String?
    dynamic var timestamp: Double = 0
    dynamic var geometry: Geometry?
    dynamic var properties: LocationProperties?
    dynamic var type = "Feature"
    
    override class func primaryKey() -> String? {
        return "docId"
    }
    
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: AnyObject, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    init(docId: String?, latitude: Double, longitude: Double, username: String, sessionId: String?, timestamp: NSDate, background: Bool?) {
        self.docId = docId
        self.timestamp = (NSDate().timeIntervalSince1970 * 1000)
        self.geometry = Geometry(latitude: latitude, longitude: longitude)
        self.properties = LocationProperties()
        self.properties?.username = username
        self.properties?.sessionId = sessionId
        self.properties?.timestamp = self.timestamp
        self.properties?.background = (background == nil ? false : background!)
        //
        super.init()
    }
}
