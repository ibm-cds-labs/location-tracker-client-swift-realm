//
//  MapViewController.swift
//  LocationTracker
//
//  Created by Mark Watson on 4/4/16.
//  Copyright © 2016 Mark Watson. All rights reserved.
//

import CouchDBRealmSync
import CoreLocation
import MapKit
import RealmSwift
import UIKit

class MapViewController: UIViewController, LocationMonitorDelegate {

    @IBOutlet weak var mapView : MKMapView?
    var mapDelegate: MapDelegate?
    var resetZoom = true
    var lastLocationObjectMapDownload: LocationObject? = nil
    var realm: Realm?
    var replicationManager: ReplicationManager?
    var placeObjects: [PlaceObject] = []
    var placePins: [MapPin] = []
    var locationObjects: [LocationObject] = []
    var locationPins: [MapPin] = []
    var locationReplications = [SyncDirection: Replicator]()
    var locationReplicationsPending : [SyncDirection: Bool] = [.Push:false,.Pull:false]
    var notificationToken: NotificationToken?
    
    // Define two sync directions: push and pull.
    // .Push will copy local data from LocationTracker to Cloudant.
    // .Pull will copy remote data from Cloudant to LocationTracker.
    enum SyncDirection {
        case Push
        case Pull
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // initialize realm
        initRealm();
        
        // initialize local places realm
        initPlacesRealm()
        
        // initialize local locatiosn realm
        initLocationsRealm()
        
        // Load all locations from realm.
        loadPlaceObjectsFromRealm()
        
        // Load all locations from realm.
        loadLocationObjectsFromRealm()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // initialize the map provider (or reset if map type changed in settings)
        initMapProvider();
        
        // Sync locations when we start up
        // This will pull the 100 most recent locations from Cloudant
        syncLocations(.Pull)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // reset the zoom and download offline maps if there are docs
        if (self.locationObjects.count > 0) {
            self.resetZoom = true
            self.resetMapZoom(self.locationObjects.last!);
        }
        
        // subscribe to locations
        LocationMonitor.instance.addDelegate(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        // user logged out
        if (AppState.username == nil) {
            // stop monitoring locations
            LocationMonitor.instance.removeDelegate(self)
            // clear realm
            try! realm?.write {
                realm?.deleteAll()
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Navigation Item Button Handlers
    
    @IBAction func logoutButtonPressed() {
        UsernamePasswordStore.deleteUsernamePassword()
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    @IBAction func settingsButtonPressed() {
        self.performSegueWithIdentifier("ShowMapSettings", sender: self)
    }
    
    // MARK: Map Provider
    
    func initMapProvider() {
        var mapProviderChanged: Bool = false
        if (self.mapDelegate == nil) {
            mapProviderChanged = true
        }
        else {
            mapProviderChanged = (AppState.mapProvider != self.mapDelegate?.providerId())
        }
        if (mapProviderChanged) {
            self.resetZoom = true;
            let previousMapDelegate = (self.mapDelegate != nil)
            if (previousMapDelegate) {
                // if switching from one map delegate to another then
                // delete downloaded maps on the previous delegate
                // and reset lastLocationObjectMapDownload to trigger a download
                self.lastLocationObjectMapDownload = nil
            }
            if (previousMapDelegate) {
                // if the map provider changed then remove all pins from the previous map provider
                self.removeAllPlacePins()
                self.removeAllLocationPins()
            }
            self.mapDelegate = MapKitMapDelegate(mapView: self.mapView!)
            self.mapView?.hidden = false
            if (previousMapDelegate) {
                // if the map provider changed then add all pins to the new map provider
                self.addAllLocationPins()
                self.addAllPlacePins()
            }
        }
        // set style every time
        self.mapDelegate?.setStyle(AppState.mapStyleId)
    }
    
    func resetMapZoom(lastLocationObject: LocationObject) {
        if (self.resetZoom) {
            self.resetZoom = false
            let coordinate: CLLocationCoordinate2D  = CLLocationCoordinate2D(latitude: lastLocationObject.geometry!.latitude, longitude: lastLocationObject.geometry!.longitude)
            self.mapDelegate?.centerAndZoom(coordinate, radiusMeters:AppConstants.initialMapZoomRadiusMiles*AppConstants.metersPerMile, animated:true)
        }
    }
    
    // MARK: LocationMonitorDelegate Members
    
    func locationManagerEnabled() {
    }
    
    func locationManagerDisabled() {
    }
    
    func locationUpdated(location:CLLocation, inBackground: Bool) {
        // create location document
        let locationObject = LocationObject(docId: NSUUID().UUIDString, latitude: location.coordinate.latitude, longitude:location.coordinate.longitude, username:AppState.username!, sessionId: AppState.sessionId, timestamp: NSDate(), background: inBackground)
        // add location to map
        self.addLocation(locationObject, drawPath: true, drawRadius: true)
        // reset map zoom
        self.resetMapZoom(locationObject)
        // save location to datastore
        createLocationObject(locationObject)
        // push locations
        syncLocations(.Push)
        // sync places based on latest location
        self.getPlaces(locationObject)
    }
    
    // MARK: Map Locations
    
    func addLocation(locationObject: LocationObject, drawPath: Bool, drawRadius: Bool) {
        self.locationObjects.append(locationObject)
        self.addLocationPin(locationObject, title: "\(self.locationObjects.count)", drawPath: drawPath, drawRadius: drawRadius)
    }
    
    func addLocationPin(locationObject: LocationObject, title: String, drawPath: Bool, drawRadius: Bool) {
        if (self.mapDelegate != nil) {
            let pin = self.mapDelegate!.getPin(
                CLLocationCoordinate2DMake(locationObject.geometry!.latitude, locationObject.geometry!.longitude),
                title: title,
                color: UIColor.blueColor()
            )
            self.locationPins.append(pin)
            self.mapDelegate!.addPin(pin)
            if (drawPath) {
                self.drawLocationPath()
            }
            if (drawRadius) {
                self.drawLocationRadius(locationObject)
            }
        }
    }
    
    func addAllLocationPins() {
        for (index,locationObject) in self.locationObjects.enumerate() {
            self.addLocationPin(locationObject, title: "\(index+1)" , drawPath: false, drawRadius: false)
        }
        self.drawLocationPath()
    }
    
    func removeAllLocations() {
        self.removeAllLocationPins();
        self.locationObjects.removeAll()
    }
    
    func removeAllLocationPins() {
        self.locationPins.removeAll()
        self.mapDelegate?.eraseRadius()
        self.mapDelegate?.erasePath()
        self.mapDelegate?.removePins(locationPins)
    }
    
    func drawLocationPath() {
        // create an array of coordinates from allPins
        var coordinates: [CLLocationCoordinate2D] = [];
        for pin: MapPin in self.locationPins {
            coordinates.append(pin.coordinate)
        }
        self.mapDelegate?.drawPath(coordinates)
    }
    
    func drawLocationRadius(locationObject:LocationObject) {
        self.mapDelegate?.drawRadius(CLLocationCoordinate2DMake(locationObject.geometry!.latitude, locationObject.geometry!.longitude), radiusMeters: AppConstants.placeRadiusMeters)
    }
    
    // MARK: Map Places
    
    func addPlace(placeObject: PlaceObject) {
        var placeExists = false
        for place in self.placeObjects {
            if (place.docId == placeObject.docId) {
                placeExists = true
                break
            }
        }
        if (placeExists == false) {
            self.placeObjects.append(placeObject)
            self.addPlacePin(placeObject)
        }
    }
    
    func addPlacePin(placeObject: PlaceObject) {
        if (self.mapDelegate != nil) {
            let pin = self.mapDelegate!.getPin(
                CLLocationCoordinate2DMake(placeObject.geometry!.latitude, placeObject.geometry!.longitude),
                title: placeObject.name!,
                color: UIColor.greenColor()
            )
            self.placePins.append(pin)
            self.mapDelegate!.addPin(pin)
        }
    }
    
    func addAllPlacePins() {
        for placeObject: PlaceObject in self.placeObjects {
            self.addPlacePin(placeObject)
        }
    }
    
    func removeAllPlaces() {
        self.removeAllPlacePins();
        self.placeObjects.removeAll()
    }
    
    func removeAllPlacePins() {
        self.placePins.removeAll()
        self.mapDelegate?.removePins(self.placePins)
    }
    
    // MARK: Realm
    
    func initRealm() {
        try! realm = Realm()
        self.replicationManager = ReplicationManager(realm: realm!)
    }
    
    // MARK: Places Realm
    
    func initPlacesRealm() {
        // not replicating - nothing to do
    }
    
    func createPlaceObject(placeObject: PlaceObject) {
        try! realm?.write {
            realm?.add(placeObject)
        }
    }
    
    func loadPlaceObjectsFromRealm() {
        let result = realm?.objects(PlaceObject.self).sorted("timestamp")
        guard result != nil else {
            print("Failed to query for places")
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.removeAllPlaces()
            for doc in result! {
                self.addPlace(doc)
            }
        })
    }
    
    func getPlaces(lastLocation: LocationObject) {
        let url = NSURL(string: "\(AppConstants.baseUrl)/api/places?lat=\(lastLocation.geometry!.latitude)&lon=\(lastLocation.geometry!.longitude)&radius=\(AppConstants.placeRadiusMeters)&relation=contains&nearest=true&include_docs=true")
        let session = NSURLSession.sharedSession()
        let request = NSMutableURLRequest(URL: url!)
        request.addValue("application/json", forHTTPHeaderField:"Content-Type")
        request.addValue("application/json", forHTTPHeaderField:"Accepts")
        request.HTTPMethod = "GET"
        //
        let task = session.dataTaskWithRequest(request) {
            (let data, let response, let error) in
            NSOperationQueue.mainQueue().addOperationWithBlock {
                guard let _:NSData = data, let _:NSURLResponse = response where error == nil else {
                    // fail silently
                    return
                }
                var dict: NSDictionary!
                do {
                    dict = try NSJSONSerialization.JSONObjectWithData(data!, options:[]) as? NSDictionary
                }
                catch {
                    print(error)
                }
                if (dict != nil) {
                    if let rows = dict["rows"] as? [[String:AnyObject]] {
                        for row in rows {
                            if let placeObject = PlaceObject(aDict: row) {
                                self.addPlace(placeObject)
                                self.createPlaceObject(placeObject)
                            }
                        }
                    }
                }
            }
        }
        //
        task.resume()
    }
    
    // MARK: Locations Realm
    
    func initLocationsRealm() {
        self.replicationManager?.register(LocationObjectManager())
    }
    
    func createLocationObject(locationObject: LocationObject) {
        try! realm!.write {
            realm!.add(locationObject)
        }
    }
    
    func loadLocationObjectsFromRealm() {
        let result = realm?.objects(LocationObject.self).sorted("timestamp", ascending: false)
        guard result != nil else {
            print("Failed to query for locations")
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.removeAllLocations()
            // we are loading the documents from most recent to least recent
            // we want our array to be in the oppsite order
            // so we can draw our path and when we add new locations we increment the label
            // here we enumerate the documents and add them to a local array in reverse order
            // then we loop through that local array and add them one by one to the map
            var docs: [LocationObject] = []
            for doc in result! {
                docs.insert(doc, atIndex: 0)
            }
            for doc in docs {
                self.addLocation(doc, drawPath: false, drawRadius: false)
            }
            self.drawLocationPath()
        })
    }
    
    // Return an NSURL to the database, with authentication.
    func locationsEndpoint() -> CouchDBEndpoint {
        var hostProtocol = AppState.locationDbHostProtocol;
        if (hostProtocol == nil) {
            hostProtocol = "https"
        }
        let baseUrl = "\(hostProtocol!)://\(AppState.locationDbHost!)"
        return CouchDBEndpoint(baseUrl: baseUrl, username: AppState.username!, password: AppState.password!, db: AppState.locationDbName!)
    }
    
    // Push or pull local data to or from the central cloud.
    func syncLocations(direction: SyncDirection) {
        dispatch_async(dispatch_get_main_queue(), {
            let existingReplication = self.locationReplications[direction]
            guard existingReplication == nil else {
                print("Ignore \(direction) replication; already running")
                self.locationReplicationsPending[direction] = true
                return
            }
            do {
                if (direction == .Pull) {
                    self.locationReplications[direction] = try! self.replicationManager?.pull(self.locationsEndpoint(), target: LocationObject.self)
                }
                else {
                    self.locationReplications[direction] = try! self.replicationManager?.push(LocationObject.self, target: self.locationsEndpoint())
                }
                if (self.locationReplications[direction] != nil) {
                    try self.locationReplications[direction]!.start({ (result) in
                        self.replicatorComplete(result)
                    })
                }
            }
            catch {
                print("Error initializing \(direction) sync: \(error)")
                return
            }
            
            print("Started \(direction) sync for locations")
        })
    }
    
    func replicatorComplete(result: ReplicationResult) {
        if (result.success == false) {
            print("Replication Error: \(result.error)")
        }
        // if location replicator and pull OR place replicator and pull
        else if (result.replicator === locationReplications[.Pull]) {
            if (result.changesProcessed > 0) {
                // Reload the locations, and refresh the UI.
                loadLocationObjectsFromRealm()
            }
        }
        self.clearReplicator(result.replicator)
    }
    
    func clearReplicator(replicator: Replicator!) {
        dispatch_async(dispatch_get_main_queue(), {
            if (replicator === self.locationReplications[.Push] || replicator === self.locationReplications[.Pull]) {
                // Determine the replication direction, given the replicator argument.
                let direction = (replicator === self.locationReplications[.Push])
                    ? SyncDirection.Push
                    : SyncDirection.Pull
                print("Clear location replication: \(direction)")
                self.locationReplications[direction] = nil
                if (self.locationReplicationsPending[direction] == true) {
                    self.locationReplicationsPending[direction] = false
                    self.syncLocations(direction)
                }
            }
        })
    }

}

