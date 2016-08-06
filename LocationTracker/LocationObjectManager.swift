//
//  LocationObjectManager.swift
//  LocationTracker
//
//  Created by Mark Watson on 8/3/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import CouchDBRealmSync
import Foundation
import Realm
import RealmSwift

class LocationObjectManager: RealmObjectManager<LocationObject> {
    
    init() {
        super.init(idField:"docId", type:LocationObject.self)
    }
    
    override func objectToDictionary(object: LocationObject) -> [String:AnyObject] {
        var dict:[String:AnyObject] = [String:AnyObject]();
        dict["type"] = "Feature"
        dict["created_at"] = object.timestamp
        dict["geometry"] = self.geometryToDictionary(object.geometry)
        dict["properties"] = self.propertiesToDictionary(object.properties)
        return dict
    }
    
    func geometryToDictionary(geometry: Geometry?) -> [String:AnyObject] {
        var dict:[String:AnyObject] = [String:AnyObject]();
        if (geometry != nil) {
            dict["type"] = "Point"
            dict["coordinates"] = [geometry!.longitude,geometry!.latitude]
        }
        return dict
    }
    
    func propertiesToDictionary(properties: LocationProperties?) -> [String:AnyObject] {
        var dict:[String:AnyObject] = [String:AnyObject]();
        if (properties != nil) {
            dict["username"] = properties!.username
            dict["sessionId"] = properties!.sessionId
            dict["timestamp"] = properties!.timestamp
            dict["background"] = properties!.background
        }
        return dict
    }
    
    override func objectFromDictionary(dict: [String:AnyObject]) -> LocationObject {
        let docId = dict["_id"] as! String
        var geometry = dict["geometry"] as? [String:AnyObject]
        var coordinates = geometry!["coordinates"] as? [Double]
        let latitude = coordinates![1]
        let longitude = coordinates![0]
        var properties = dict["properties"] as? [String:AnyObject]
        let username = properties!["username"] as! String
        let sessionId = properties!["session_id"] as? String
        let timestamp = properties!["timestamp"] as? Double
        let background = properties!["background"] as? Bool
        return LocationObject(docId: docId, latitude: latitude, longitude: longitude, username: username, sessionId: sessionId, timestamp: NSDate(timeIntervalSince1970: Double(timestamp!)/1000.0), background: background)
    }
    
    override func updateObjectWithDictionary(object: LocationObject, dict: [String : AnyObject]) {
        var geometry = dict["geometry"] as? [String:AnyObject]
        var coordinates = geometry!["coordinates"] as? [Double]
        let latitude = coordinates![1]
        let longitude = coordinates![0]
        var properties = dict["properties"] as? [String:AnyObject]
        let username = properties!["username"] as! String
        let sessionId = properties!["session_id"] as? String
        let timestamp = properties!["timestamp"] as? Double
        let background = properties!["background"] as? Bool
        //
        object.timestamp = timestamp ?? (NSDate().timeIntervalSince1970 * 1000)
        object.geometry = Geometry(latitude: latitude, longitude: longitude)
        if (object.properties == nil) {
            object.properties = LocationProperties()
        }
        object.properties?.username = username
        object.properties?.sessionId = sessionId
        object.properties?.timestamp = object.timestamp
        object.properties?.background = (background == nil ? false : background!)
    }
    
}
