//
//  FirstViewController.swift
//  EAB_Tracker
//
//  Created by Caleb Mackey on 2/2/16.
//  Copyright © 2016 Caleb Mackey. All rights reserved.
//

import UIKit
import Foundation
import ArcGIS
import MessageUI
import LocalAuthentication

let kBasemapLayerName = "Basemap"
var isAdmin = false
var isAdminJson = String(isAdmin)

//The geocode service
let baseUrl = "https://maps.googleapis.com/maps/api/geocode/json?"
let kGeoLocatorURL = "http://gis.hennepin.us/arcgis/rest/services/Locators/HC_COMPOSITE/GeocodeServer"
let aerialURL = "http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer"

class MapViewController: UIViewController, AGSWebMapDelegate, AGSCalloutDelegate, AGSMapViewTouchDelegate, AGSPopupsContainerDelegate, FeatureTemplateDelegate, AGSFeatureLayerQueryDelegate, AGSLocatorDelegate, AGSAttachmentManagerDelegate, AGSFeatureLayerEditingDelegate, AGSMapViewLayerDelegate, UIImagePickerControllerDelegate, MFMailComposeViewControllerDelegate,
    UINavigationControllerDelegate {
    
    // map
    @IBOutlet weak var mapView: AGSMapView!
    
    var activityIndicator:UIActivityIndicatorView!
    var popupVC:AGSPopupsContainerViewController!
    var countiesFST:AGSGDBFeatureServiceTable!
    var sightingsFST:AGSGDBFeatureServiceTable!
    var counties:AGSFeatureLayer!
    var countiesPopup: AGSPopupInfo!
    var sightingsPopup:AGSPopupInfo!
    var locator:AGSLocator!
    var sightings:AGSFeatureLayer!
    var webMap:AGSWebMap!
    var locationDisplay:AGSLocationDisplay!
    var location:AGSLocation!
    var mapPoint:AGSPoint!
    var webMapId:String!
    var popupFeatures:String!
    var streetBasemap:AGSWebMapBaseMap!
    var aerialBasemap:AGSWebMapBaseMap!
    var graphicsLayer:AGSGraphicsLayer!
    var newSighting: AGSGraphic!
    var isAddingNew = false
    var featureTemplatePickerController:FeatureTemplatePickerController!
    var imagePickerController: UIImagePickerController?
    
    // array for stored photos from user
    var collectedImages: [String:NSData] = [:]
    
    // UI vars
    @IBOutlet weak var loginButton: UIBarButtonItem!
    @IBOutlet weak var bannerView: UIToolbar!
    @IBOutlet weak var addSightingLabel: UIBarButtonItem!
    @IBOutlet weak var pickTemplateButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a webmap and open it into the map
        self.webMapId = "caee4b7fdf5c49c285995b5d1b25e123"
        self.webMap = AGSWebMap(itemId: self.webMapId, credential: nil)
        self.webMap.delegate = self
        self.webMap.openIntoMapView(self.mapView)
        
        // mapview delegates
        self.mapView.layerDelegate = self
        self.mapView.touchDelegate = self
        self.mapView.callout.delegate = self
        self.mapView.showMagnifierOnTapAndHold = true
        
        //Initialize the template picker view controller
        let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
        self.featureTemplatePickerController = storyboard.instantiateViewControllerWithIdentifier("FeatureTemplatePickerController") as! FeatureTemplatePickerController
        self.featureTemplatePickerController.delegate = self
        
    }
    
    @IBAction func launchLogin(sender: AnyObject) {
        if !isAdmin {
            Login()
        } else {
            isAdmin = false
            dispatch_async(dispatch_get_main_queue(), {
                self.loginButton.title = "Login"
            })
        }
    }
    
    //****************************************************************************************
    //
    // MARK: webmap delegates, layers and setup
    //
    // set up basemap options for segmented view
    func webMapDidLoad(webMap: AGSWebMap!) {
        // street basemap as default
        streetBasemap = webMap.baseMap as AGSWebMapBaseMap
    
        // aerial photo
        var aerialJson = [NSObject:AnyObject]()
        aerialJson["title"] = "Aerial Imagery"
        let layers: [[String:String]] = [["url": aerialURL]]
        aerialJson["baseMapLayers"] = layers
        aerialBasemap = AGSWebMapBaseMap(JSON: aerialJson)
        
    }
    
    // load layers, set feature layer template picker to sightings
    func webMap(webMap: AGSWebMap!, didLoadLayer layer: AGSLayer!) {
        if let featureLayer = layer as? AGSFeatureLayer {
            if (featureLayer.name == "EAB Sighting"){
                self.sightings = featureLayer
    
                self.sightings.editingDelegate = self
                
                //Add templates from this layer to the Feature Template Picker
                self.featureTemplatePickerController.addTemplatesFromLayer(self.sightings)
            
            }
            else if (featureLayer.name == "County Boundary"){
                self.counties = featureLayer
                self.counties.editingDelegate = self
                self.counties.queryDelegate = self
                
                // now display user location
                self.locationDisplay = self.mapView.locationDisplay
                self.locationDisplay.startDataSource()
                self.locationDisplay.autoPanMode = .Default
                self.locationDisplay.wanderExtentFactor = 0.75
                
                // register location
                registerLocation()
            }
        }
    }

    
    // skip if fails to load layer
    func webMap(webMap: AGSWebMap!, didFailToLoadLayer layerInfo: AGSWebMapLayerInfo!, baseLayer: Bool, federated: Bool, withError error: NSError!) {
        print("Failed to load layer : \(layerInfo.title)")
        
        //continue anyway
        self.webMap.continueOpenAndSkipCurrentLayer()
    }
    
    // failed to load layer
    func webMap(webMap: AGSWebMap!, didFailToLoadWithError error: NSError!) {
        print("Error loading webmap!")
        print(error)
    }
    
    
    // AGSFeatureLayerEditingDelegate methods
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didFeatureEditsWithResults editResults: AGSFeatureLayerEditResults!) {
        
        var updateAttachments = true
        
        if editResults.addResults != nil && editResults.addResults.count > 0 {
            //we were adding a new feature
            let result = editResults.addResults[0] as! AGSEditResult
            if !result.success {
                //Add operation failed. We will not update attachments
                updateAttachments = false
                //Inform user
                //self.warnUserOfErrorWithMessage("Could not add feature. Please try again")
                print("Could not add feature. Please try again")
            }
        }
        else if editResults.updateResults != nil && editResults.updateResults.count > 0 {
            //we were updating a feature
            let result = editResults.updateResults[0] as! AGSEditResult
            if !result.success {
                //Update operation failed. We will not update attachments
                updateAttachments = false
                //Inform user
                //self.warnUserOfErrorWithMessage("Could not update feature. Please try again")
                print("Could not update feature. Please try again")
            }
        }
        else if editResults.deleteResults != nil && editResults.deleteResults.count > 0 {
            //we were deleting a feature
            updateAttachments = false
            let result = editResults.deleteResults[0] as! AGSEditResult
            if !result.success {
                //Delete operation failed. Inform user
                //self.warnUserOfErrorWithMessage("Could not delete feature. Please try again")
                print("Could not delete feature. Please try again")
            }
            else {
                //Delete operation succeeded
                //Dismiss the popup view controller and hide the callout which may have been shown for the deleted feature.
                self.mapView.callout.hidden = true
                self.dismissViewControllerAnimated(true, completion:nil)
                self.popupVC = nil
            }
        }
        
        //if edits pertaining to the feature were successful...
        if (updateAttachments && featureLayer.attachments){
            
            //...we post edits to the attachments
            let attMgr = featureLayer.attachmentManagerForFeature(self.popupVC.currentPopup.graphic)
            //let attMgr = featureLayer.attachmentManagerForFeature(self.newSighting)
            attMgr.delegate = self
            
            // add Attachments(attMgr.featureObjectId)
            /*
            for (img, imgData) in self.collectedImages {
                let oid = attMgr.featureObjectId
                attMgr.addAttachmentWithData(imgData, name: img, contentType: "image/png")
                print("added attachment \(img) for ID \(oid)")
            }*/
            
            // ORIGINALLY DELETING HERE, REMOVE IF DELETING AFTER SENDING AS EMAIL ATTACHMENTS
            //self.collectedImages.removeAll()
            
            print("count of attachments \(attMgr.attachments.count), \(attMgr.hasLocalEdits()) ")
            if attMgr.hasLocalEdits() {
                attMgr.postLocalEditsToServer()
                print("posted local edits")
                self.dismissViewControllerAnimated(true, completion:nil)
                self.popupVC = nil
                
                // send email to arrest the pest
                let msg = "new sighting"
                /*
                do {
                    let msg1 = try NSJSONSerialization.dataWithJSONObject(self.popupVC.currentPopup.graphic.allAttributes(), options: NSJSONWritingOptions.PrettyPrinted)
                    // here "jsonData" is the dictionary encoded in JSON data
                } catch let error as NSError {
                    print(error)
                }
 */
                let subj = "new sighting in county"
                let mailComposeViewController = configuredMailComposeViewController(msg, subject: subj)
                if MFMailComposeViewController.canSendMail() {
                    self.presentViewController(mailComposeViewController, animated: true, completion: nil)
                } else {
                    self.showSendMailErrorAlert()
                }

                // end email
            }
        }
    }
    
    // attachment error
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didFailAttachmentEditsWithError error: NSError!) {
        print(error)
    }
    
    // attachment edit results
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didAttachmentEditsWithResults attachmentResults: AGSFeatureLayerAttachmentResults!) {
        let results = attachmentResults.addResult
        if !results.success {
            print(results.error)
        }
        else {
            print("delegate: added attachment successfully")
        }
        /*
        // send email to arrest the pest
        let msg = "new sighting"
        let subj = "new sighting in county"
        let mailComposeViewController = configuredMailComposeViewController(msg, subject: subj)
        if MFMailComposeViewController.canSendMail() {
            self.presentViewController(mailComposeViewController, animated: true, completion: nil)
        } else {
            self.showSendMailErrorAlert()
        }
        */
    }
    
    
    // query features from touch delegate for mapview
    func mapView(mapView: AGSMapView!, didClickAtPoint screen: CGPoint, mapPoint mappoint: AGSPoint!, features: [NSObject : AnyObject]!) {
        
        let geometryEngine = AGSGeometryEngine.defaultGeometryEngine()
        let buffer = geometryEngine.bufferGeometry(mappoint, byDistance:(10 * mapView.resolution))
        let willFetch = self.webMap.fetchPopupsForExtent(buffer.envelope)
        if !willFetch {
            // TODO: better handling here
            print("Sorry, try again")
        }
        else {
            self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
            self.mapView.callout.customView = self.activityIndicator
            self.activityIndicator.startAnimating()
            self.mapView.callout.showCalloutAt(mappoint, screenOffset:CGPointZero, animated:true)
        }
        self.popupVC = nil
        
    }
    
    
    //****************************************************************************************
    //
    // MARK: register observer for location change events
    func registerLocation() {
        self.mapView.locationDisplay.addObserver(self, forKeyPath: "location", options: .New, context: nil)
        print("registered location...")
    }
    
    func unregisterLocation(){
        self.mapView.locationDisplay.removeObserver(self, forKeyPath: "location")
        print("unregistered location.")
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "location" {
            self.location = self.mapView.locationDisplay.location
            
        }
    }

    
    //****************************************************************************************
    //
    // MARK: function to add a sighting
    func addSighting(template: AGSFeatureTemplate) {
        self.isAddingNew = true
        self.popupVC = nil
        
        let newPoint = AGSGeometryEngine().projectGeometry(self.location.point, toSpatialReference: AGSSpatialReference.webMercatorSpatialReference())
        
        // create template
        self.newSighting = self.sightings.featureWithTemplate(template)
        
        // set additional attributes
        let address = reverseGeocode(String(self.location.point.y), longitude: String(self.location.point.x))
        self.newSighting.setAttribute(self.location.point.x, forKey: "Latitude")
        self.newSighting.setAttribute(self.location.point.y, forKey: "Longitude")
        self.newSighting.setAttribute(address, forKey: "Site_Address")
        self.newSighting.geometry = newPoint
        
        // add it as a graphic
        self.sightings.addGraphic(self.newSighting)
        
        // get attachment manager for this feature
        var attMgr = self.sightings.attachmentManagerForFeature(newSighting)
        attMgr.delegate = self
        
        // add Attachments here so it can be found in attachment manager, does not actually get added yet
        for (img, imgData) in self.collectedImages {
            attMgr.addAttachmentWithData(imgData, name: img, contentType: "image/jpg")
            print("added attachment \(img)")
        }
        attMgr = nil
        
        // Iniitalize popup view controller
        self.popupVC = AGSPopupsContainerViewController(webMap: self.webMap, forFeature: self.newSighting, usingNavigationControllerStack: false)
        self.popupVC.delegate = self
        
        
        //Only for iPad, set presentation style to Form sheet
        //We don't want it to cover the entire screen
        self.popupVC.style = .Default
        self.popupVC.delegate = self
        self.popupVC.modalPresentationStyle = .FormSheet
        
        //Animate by flipping horizontally
        self.popupVC.modalTransitionStyle = .FlipHorizontal
        
        //First, dismiss the Feature Template Picker
        self.dismissViewControllerAnimated(false, completion:nil)
        
        //Next, Present the popup view controller
        self.presentViewController(self.popupVC, animated: true) { () -> Void in
            self.popupVC.startEditingCurrentPopup()
        }
    }
    
    // function add attachments
    func addAttachments(oid: Int) -> Void {
        for (img, imgData) in self.collectedImages {
            let oidAsUInt: UInt = UInt(oid)
            self.sightings.addAttachment(oidAsUInt, data:imgData, filename: img)
            print("added attachment \(img) for ID \(oid)")
        }
        self.collectedImages.removeAll()
    }

    
    //****************************************************************************************
    //
    // MARK: Feature Templates
    func featureTemplatePickerViewControllerWasDismissed(controller: FeatureTemplatePickerController) {
        self.collectedImages.removeAll()
        self.dismissViewControllerAnimated(true, completion: nil)
        
    }
    
    func featureTemplatePickerViewController(controller: FeatureTemplatePickerController, didSelectFeatureTemplate template: AGSFeatureTemplate, forFeatureLayer featureLayer: AGSFeatureLayer) {
        
        //create a new feature based on the template
        addSighting(template)
        
    }
    
    //****************************************************************************************
    //
    // MARK: reverse geocoder using Google 
    func reverseGeocode(latitude: String, longitude: String) -> String {
        let url = NSURL(string: "\(baseUrl)latlng=\(latitude),\(longitude)&sensor=true")
        var address:NSString!
        let data = NSData(contentsOfURL: url!)
        let json = try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
        if let result = json["results"] as? NSArray {
            address = result[0]["formatted_address"] as! String
            
        }
        return address as String
    }
    
    //****************************************************************************************
    //
    // MARK: Popups View Controller
    //
    // fetch popups from user
    func webMap(webMap: AGSWebMap!, didFetchPopups popups: [AnyObject]!, forExtent extent: AGSEnvelope!) {
        // If we've found one or more popups
        if popups.count > 0 {
            
            if self.popupVC == nil {
                //Create a popupsContainer view controller with the popups
                self.popupVC = AGSPopupsContainerViewController(popups: popups, usingNavigationControllerStack: false)
                self.popupVC.style = .Default
                self.popupVC.delegate = self
                
            }else{
                self.popupVC.showAdditionalPopups(popups)
            }
            
            // For iPad, display popup view controller in the callout
            if AGSDevice.currentDevice().isIPad() {
                self.mapView.callout.customView = self.popupVC.view
                
                //set the modal presentation options for subsequent popup view transitions
                self.popupVC.modalPresenter =  self
                self.popupVC.modalPresentationStyle = .FormSheet
                
            }
            else {
                //For iphone, display summary info in the callout
                self.mapView.callout.title = "\(self.popupVC.popups.count) Results"
                self.mapView.callout.accessoryButtonHidden = false
                self.mapView.callout.detail = "view details..."
                self.mapView.callout.customView = nil
            }
            
            if (isAdmin == false) {
                // Start the activity indicator in the upper right corner of the
                // popupsContainer view controller while we wait for the query results
                self.activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
                let blankButton = UIBarButtonItem(customView: self.activityIndicator)
                self.popupVC.actionButton = blankButton
                self.activityIndicator.startAnimating()
            }
            
        }
    }
    
    // present popup view controller
    func didClickAccessoryButtonForCallout(callout: AGSCallout!) {
        self.presentViewController(self.popupVC, animated:true, completion:nil)
    }
    
    
    // - AGSPopupsContainerDelegate methods
    func popupsContainerDidFinishViewingPopups(popupsContainer: AGSPopupsContainer!) {
        
        // If we are on iPad dismiss the callout
        if AGSDevice.currentDevice().isIPad() {
            self.mapView.callout.hidden = true
            self.dismissViewControllerAnimated(true, completion:nil) // not in esri sample
        }
        else {
            //dismiss the modal viewcontroller for iPhone
            self.dismissViewControllerAnimated(true, completion:nil)
            self.mapView.callout.hidden = true
        }
    }
    
    // Apply edits after popup has been edited
    func popupsContainer(popupsContainer: AGSPopupsContainer!, wantsToDeleteForPopup popup: AGSPopup!) {
        //Call method on feature layer to delete the feature
        if (popup.featureLayer.name == "EAB Sighting"){
            let number = popup.featureLayer.objectIdForFeature(popup.graphic)
            let oids = [NSNumber(longLong: number)]
            popup.featureLayer.deleteFeaturesWithObjectIds(oids)
            print("deleting EAB Sighting: \(oids)")
        }
    }
    
    // finish editing popup
    func popupsContainer(popupsContainer: AGSPopupsContainer!, didFinishEditingForPopup popup: AGSPopup!) {
        // simplify the geometry, this will take care of self intersecting polygons and
        popup.graphic.geometry = AGSGeometryEngine.defaultGeometryEngine().simplifyGeometry(popup.graphic.geometry)
        //normalize the geometry, this will take care of geometries that extend beyone the dateline
        popup.graphic.geometry = AGSGeometryEngine.defaultGeometryEngine().normalizeCentralMeridianOfGeometry(popup.graphic.geometry)
        
        let oid = popup.featureLayer.objectIdForFeature(popup.graphic)
        
        if oid > 0 {
            //feature has a valid objectid, this means it exists on the server
            //and we simply update the exisiting feature
            print("updating feature with OID \(oid)")
            popup.featureLayer.updateFeatures([popup.graphic])
            
        }
        else {
            //objectid does not exist, this means we need to add it as a new feature
            popup.featureLayer.addFeatures([popup.graphic])
            //popup.featureLayer.applyEditsWithFeaturesToAdd([popup.graphic], toUpdate: nil, toDelete: nil)
            
            
            // query counties to see if there is a new sighting within
            if (popup.featureLayer.name == "EAB Sighting") {
                queryCounties()
            }
            
        }
        
        /*
        // clear graphics for new sighting
        if self.newSighting != nil {
            //self.sightings.removeGraphic(self.newSighting)
            //self.sightings.removeAllGraphics()
            self.newSighting = nil
        }*/

    }
    
    func popupsContainer(popupsContainer: AGSPopupsContainer!, didCancelEditingForPopup popup: AGSPopup!) {
        //dismiss the popups view controller
        self.dismissViewControllerAnimated(true, completion:nil)
        self.collectedImages.removeAll()
        
        //if we had begun adding a new feature, remove it from the layer because the user hit cancel.
        if self.newSighting != nil {
            //self.sightings.removeGraphic(self.newSighting)
            self.sightings.removeAllGraphics()
            self.newSighting = nil
        }
        
        //reset any sketch related changes we made to our main view controller
        self.mapView.touchDelegate = self
        self.mapView.callout.delegate = self
        self.popupVC = nil
    }
    
    
    //****************************************************************************************
    //
    //MARK: - AGSAttachmentManagerDelegate
    
    func attachmentManager(attachmentManager: AGSAttachmentManager!, didPostLocalEditsToServer attachmentsPosted: [AnyObject]!) {
        
        //loop through all attachments looking for failures
        var anyFailure = false
        
        for attachment in attachmentsPosted as! [AGSAttachment] {
            if attachment.networkError != nil || attachment.editResultError != nil {
                anyFailure = true
                var reason:String!
                if attachment.networkError != nil {
                    reason = attachment.networkError.localizedDescription
                }
                else if attachment.editResultError != nil {
                    reason = attachment.editResultError.errorDescription
                }
                print("Attachment \(attachment.attachmentInfo.name) could not be synced with server because \(reason)")
            }
            else {
                print("added attachment")
            }
        }
        
        if anyFailure {
            //self.warnUserOfErrorWithMessage("Some attachment edits could not be synced with the server. Please try again")
            print("Some attachment edits could not be synced with the server. Please try again")
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    
    // MARK: switch basemaps
    @IBAction func basemapChanged(sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: //streets
            self.webMap.switchBaseMapOnMapView(streetBasemap)
        case 1: // aerial
            self.webMap.switchBaseMapOnMapView(aerialBasemap)
        default: //streets
            self.webMap.switchBaseMapOnMapView(streetBasemap)
        }
        
    }
    
    //****************************************************************************************
    //
    //MARK: Feature Layer operations and delegates
    //
    // update counties if a new layer is found
    func queryCounties(){
        let query = AGSQuery()
        query.whereClause = "1=1"
        query.outFields = ["*"]
        query.geometry = self.newSighting.geometry
        
        self.counties.queryFeatures(query)
    }

    
    // AGSFeatureLayerQueryDelegate
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didQueryFeaturesWithFeatureSet featureSet: AGSFeatureSet!) {
        
        if (featureSet.features.count > 0) {
             var needToChange = false
             for feature in featureSet.features {
                 let status = feature.attributeAsStringForKey("QUARANTINED")
                 if (status != "Currently Quarantined" && status != "Possible EAB Present") {
                     feature.setAttributeWithString("Possible EAB Present", forKey: "QUARANTINED")
                     needToChange = true
                 }
             }
             
             // apply updates
             if (needToChange){
                 self.counties.updateFeatures(featureSet.features)
                 print("updating counties")
             }
         }
    }
    
    // more feature layer delegates
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didFailFeatureEditsWithError error: NSError!) {
        print(error)
    }
    
    func featureLayer(featureLayer: AGSFeatureLayer!, operation op: NSOperation!, didFailQueryFeaturesWithError error: NSError!) {
        print(error)
    }
    
    //****************************************************************************************
    //
    //MARK: - actions
    //
    // present feature template picker
    func presentFeatureTemplatePicker() {
        
        self.featureTemplatePickerController.modalPresentationStyle = .FormSheet
        
        self.presentViewController(self.featureTemplatePickerController, animated: true, completion: nil)
    }
    
    //****************************************************************************************
    //
    //MARK: - actions
    //
    // get photos from user
    @IBAction func takePhoto(sender: UIBarButtonItem) {
        registerLocation()
        // clear collected photos
        self.collectedImages.removeAll()
        
        // Allow user to choose between photo library and camera
        let alertController = UIAlertController(title: nil, message: "One or more photos are required with a sighting, take a new photo or pick from photo library to continue", preferredStyle: .ActionSheet)
        
        // make sure to do a modal popover for IPad...
        if (UIDevice.currentDevice().userInterfaceIdiom == .Pad) {
            alertController.modalPresentationStyle = .Popover
        }
        
        // Only show camera option if rear camera is available
        if (UIImagePickerController.isCameraDeviceAvailable(.Rear)) {
            let cameraAction = UIAlertAction(title: "Take Photo with Camera", style: .Default) { (action) in
                // present camera
                self.showImagePickerController(.Camera)
            }
            
            alertController.addAction(cameraAction)
        }
        
        // photo library picker
        let photoLibraryAction = UIAlertAction(title: "Choose Photo from Library", style: .Default) { (action) in
            self.showImagePickerController(.PhotoLibrary)
        }
        
        alertController.addAction(photoLibraryAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) {
            (action) in
            self.collectedImages.removeAll()
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        
        alertController.addAction(cancelAction)

        
        // set presenter if IPad to avoid fatal error
        if let presenter = alertController.popoverPresentationController {
            presenter.barButtonItem = sender
        }
        
        // present view controller
        self.presentViewController(alertController, animated: true, completion: nil)
        
    }
    
    // show either camera or photo library
    func showImagePickerController(sourceType: UIImagePickerControllerSourceType) {
        imagePickerController = UIImagePickerController()
        imagePickerController!.sourceType = sourceType
        imagePickerController!.delegate = self
        
        self.presentViewController(imagePickerController!, animated: true, completion: nil)
    }
    
    // MARK: store image after user selected one
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            let imageData: NSData = UIImageJPEGRepresentation(pickedImage, 0.25)! //change to .75 before release
            let date = NSDate()
            let formatter = NSDateFormatter()
            formatter.dateFormat = "'IMG_'yyyyMMddHHmmss'.jpg'"
            formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
            formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
            let imageName = formatter.stringFromDate(date)
            print(imageName)
            self.collectedImages[imageName] = imageData
        }
        print("collected \(self.collectedImages.count) images")
        dismissViewControllerAnimated(true, completion: nil)
        
        //present feature template picker
        presentFeatureTemplatePicker()
    }
    
    // dissmiss the alertController on cancel
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    // MARK: email functionality
    func configuredMailComposeViewController(message: String, subject: String) -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self // Extremely important to set the --mailComposeDelegate-- property, NOT the --delegate-- property
        
        mailComposerVC.setToRecipients(["caleb.mackey@gmail.com"])
        mailComposerVC.setSubject(subject)
        mailComposerVC.setMessageBody(message, isHTML: false)
        
        var totalSize = 0
        for imgData in self.collectedImages.values{
            totalSize += imgData.length
        }
        for (img, imgData) in self.collectedImages {
            /*
            if (imgData.length > 4096  && self.collectedImages.count){
                // reduce file size
            }*/
            mailComposerVC.addAttachmentData(imgData, mimeType: "image/jpg", fileName: img)
        }
        print("Total size: \(totalSize)")
        
        return mailComposerVC
    }
    
    func showSendMailErrorAlert() {
        let sendMailErrorAlert = UIAlertController(title: "Could Not Send Email", message: "Your device could not send e-mail.  Please check e-mail configuration and try again.", preferredStyle: .Alert)
        presentViewController(sendMailErrorAlert, animated: true, completion: nil)
    }
    
    // MARK: MFMailComposeViewControllerDelegate Method
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        controller.dismissViewControllerAnimated(true, completion: nil)
        print("email sucessfully sent")
        self.collectedImages.removeAll()
    }
    
    // MARK: Authentication
    
    func auth_wrapper(usr: String, pw: String, handleFailure: Bool = true) -> Void {
        authenticate(usr, pw: pw)
        if isAdmin {
            dispatch_async(dispatch_get_main_queue(), {
                self.loginButton.title = "Logout"
            })
        }
        if !isAdmin && handleFailure {
            let errorAlert = UIAlertController(title: "Authentication Error", message: "Authentication Failed, please try again", preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "Ok", style: .Cancel, handler: nil)
            errorAlert.addAction(okAction)
            self.presentViewController(errorAlert, animated: true, completion: nil)
        }
    }
    func Login() -> Void {
        let context = LAContext()
        var error: NSError?
        let reason = "Authentication is required to edit data, please use Touch ID now"
        
        if context.canEvaluatePolicy(LAPolicy.DeviceOwnerAuthenticationWithBiometrics, error: &error) && hasLoginKey {
            context.evaluatePolicy(LAPolicy.DeviceOwnerAuthenticationWithBiometrics, localizedReason: reason, reply: { (success, policyError) in
                if success {
                    print("touch ID successful")
                    // grab username and password from NSUserDefaults and Keychain
                    if let storedUsername = NSUserDefaults.standardUserDefaults().valueForKey("username") as? String {
                        
                        if let password = keychainWrapper.myObjectForKey("v_Data") as? String {
                            self.auth_wrapper(storedUsername, pw: password, handleFailure: false)
                            
                        }
                    }
                    
                }
                else {
                    
                    switch policyError!.code {
                    case LAError.SystemCancel.rawValue:
                        print("touch ID error: system cancelled")
                    case LAError.UserCancel.rawValue:
                        print("touch ID error: user cancelled")
                    case LAError.UserFallback.rawValue:
                        self.showPasswordAlert()
                    default:
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                            let message = "Touch ID Authentication failed, please login with username and password"
                            let errorAlert = UIAlertController(title: "Touch ID Error", message: message, preferredStyle: .Alert)
                            let okAction = UIAlertAction(title: "Ok", style: .Cancel, handler: nil)
                            errorAlert.addAction(okAction)
                            self.presentViewController(errorAlert, animated: true, completion: nil)
                        
                        })
                    }
                }
            })
        } else {
            
            self.showPasswordAlert()
        }
        
    }
    
    func showPasswordAlert() -> Void {
        print("should be displaying password alert")
        
        let pwAlert = UIAlertController(title: "EAB Tracker Authentication", message: "Please enter your username password", preferredStyle: .Alert)
        let defaultAction = UIAlertAction(title: "OK", style: .Default) { (action) in
            if let usrField = pwAlert.textFields?[0] as UITextField? {
                if let pwField = pwAlert.textFields?[1] as UITextField? {
                    let storedUsername = usrField.text
                    let password = pwField.text
                    self.auth_wrapper(storedUsername!, pw: password!)
                    if hasLoginKey == false && isAdmin {
                        NSUserDefaults.standardUserDefaults().setValue(storedUsername, forKey: "username")
                        
                        // write password to keychain and synchronize user defaults
                        keychainWrapper.mySetObject(password, forKey:kSecValueData)
                        keychainWrapper.writeToKeychain()
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hasLoginKey")
                        NSUserDefaults.standardUserDefaults().synchronize()
                    }
                    
                }
            }
        }
        var hasUsername = false
        pwAlert.addAction(defaultAction)
        pwAlert.addTextFieldWithConfigurationHandler { (usrField) -> Void in
            if let storedUsername = NSUserDefaults.standardUserDefaults().valueForKey("username") as? String {
                usrField.text = storedUsername as String
                hasUsername = true
                print("set has username to \(hasUsername)")
            } else {
                usrField.placeholder = "username"
                usrField.becomeFirstResponder()
            }
            
        }
        print("hasusername outside of scope: \(hasUsername)")
        pwAlert.addTextFieldWithConfigurationHandler { (pwField) -> Void in
            pwField.placeholder = "password"
            pwField.secureTextEntry = true
            if hasUsername {
                pwField.becomeFirstResponder()
            }
            
            
        }
        let cancel = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        pwAlert.addAction(cancel)
        self.presentViewController(pwAlert, animated: true, completion: nil)
    }

    
}

