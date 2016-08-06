//
//  LocationProperties.swift
//  LocationTracker
//
//  Created by Mark Watson on 7/28/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import Realm
import RealmSwift

class LocationProperties : Object {
    
    dynamic var username: String?
    dynamic var sessionId: String?
    dynamic var timestamp: Double = 0
    dynamic var background: Bool = false
    
}

