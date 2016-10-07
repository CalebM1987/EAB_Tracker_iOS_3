//
//  FeatureTemplatePickerControl.swift
//  EAB_Tracker
//
//  Created by ESRI
//  From Esri sample on GitHub:
// https://github.com/Esri/arcgis-runtime-samples-ios/blob/master/FeatureLayerEditingSample/swift/FeatureLayerEditing/ViewController.swift

import UIKit
import ArcGIS

let cellIdentifier = "TemplatePickerCell"

class FeatureTemplateInfo {
    var featureType:AGSFeatureType!
    var featureTemplate:AGSFeatureTemplate!
    var featureLayer:AGSFeatureLayer!
}

protocol FeatureTemplateDelegate:class {
    func featureTemplatePickerViewControllerWasDismissed(controller:FeatureTemplatePickerController)
    func featureTemplatePickerViewController(controller:FeatureTemplatePickerController, didSelectFeatureTemplate template:AGSFeatureTemplate, forFeatureLayer featureLayer:AGSFeatureLayer)
}

class FeatureTemplatePickerController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var infos = [FeatureTemplateInfo]()
    var templates = [AGSFeatureTemplate]()
    
    
    @IBOutlet weak var featureTemplateTableView: UITableView!
    
    
    //TODO: check for weak or strong
    weak var delegate:FeatureTemplateDelegate?
    
    override func prefersStatusBarHidden() -> Bool {
        return true
     
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        featureTemplateTableView.rowHeight = UITableViewAutomaticDimension
        
        // register table
        self.featureTemplateTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        
    }
    
    func addTemplatesFromLayer(layer:AGSFeatureLayer) {
        
        //if layer contains only templates (no feature types)
        if layer.templates != nil && layer.templates.count > 0 {
            //for each template
            for template in layer.templates as! [AGSFeatureTemplate] {
                let info = FeatureTemplateInfo()
                info.featureLayer = layer
                info.featureTemplate = template
                info.featureType = nil
                
                //add to array
                self.infos.append(info)
                self.templates.append(template)
               
            }
        }
            //otherwise if layer contains feature types
        else  {
            //for each type
            for type in layer.types as! [AGSFeatureType] {
                //for each temple in type
                for template in type.templates as! [AGSFeatureTemplate] {
                    let info = FeatureTemplateInfo()
                    info.featureLayer = layer
                    info.featureTemplate = template
                    info.featureType = type
                    
                    //add to array
                    self.infos.append(info)
                    self.templates.append(template)
                
                }
            }
        }
    }
    
    @IBAction func dismiss() {
        //Notify the delegate that user tried to dismiss the view controller
        self.delegate?.featureTemplatePickerViewControllerWasDismissed(self)
    }
    
    //MARK: - table view data source
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.infos.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        //Get a cell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)!
        
        //Set its label, image, etc for the template
        let info = self.infos[indexPath.row]
        
        cell.textLabel?.text = info.featureTemplate.name
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        cell.imageView?.image = info.featureLayer.renderer.swatchForFeatureWithAttributes(info.featureTemplate.prototypeAttributes, geometryType: info.featureLayer.geometryType, size: CGSizeMake(20, 20))
        
        return cell
    }
    
    //MARK: - table view delegate
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        //Notify the delegate that the user picked a feature template
        let info = self.infos[indexPath.row]
        self.delegate!.featureTemplatePickerViewController(self, didSelectFeatureTemplate: info.featureTemplate, forFeatureLayer: info.featureLayer)
        
        //unselect the cell
        tableView.cellForRowAtIndexPath(indexPath)?.selected = false
    }
    
}
