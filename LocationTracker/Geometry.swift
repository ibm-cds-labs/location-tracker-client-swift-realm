//
//  Geometry.swift
//  LocationTracker
//
//  Created by Mark Watson on 4/4/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Realm
import RealmSwift

class Geometry: Object {
    
    dynamic var latitude: Double = 0
    dynamic var longitude: Double = 0
    
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    required init(value: AnyObject, schema: RLMSchema) {
        super.init(value: value, schema: schema)
    }
    
    init?(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        super.init()
    }
}
