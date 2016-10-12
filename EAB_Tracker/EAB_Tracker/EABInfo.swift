//
//  EABInfo.swift
//  EAB_Tracker
//
//  Created by Caleb Mackey on 5/11/16.
//  Copyright © 2016 Caleb Mackey. All rights reserved.
//
import UIKit

var defaultSize = CGSize(width: 300, height: 300)

var selectedTableResource = eabTableResource
var currentTableData = "eab"

class EABInfo: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBAction func infoChanged(sender: AnyObject) {
        switch sender.selectedSegmentIndex {
        case 0:
            if currentTableData != "eab" {
                selectedTableResource = eabTableResource
                handleRefresh(refreshControl)
                currentTableData = "eab"
                scrollToTop()
            }
        case 1:
            if currentTableData != "ash" {
                selectedTableResource = ashTableResource
                handleRefresh(refreshControl)
                currentTableData = "ash"
                scrollToTop()
            }
        default:
            if currentTableData != "eab" {
                selectedTableResource = eabTableResource
                handleRefresh(refreshControl)
                currentTableData = "eab"
                scrollToTop()
            }
        }
    }
    
    
    @IBOutlet weak var tableView: UITableView!
    let cellIdentifier = "eabCell"
    let cellSpacingHeight: CGFloat = 80
    
    @IBAction func goBackToMap(sender: AnyObject) {
        tabBar.selectedIndex = 0
    }
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        
        return refreshControl
    }()
    
    func dismissFullscreenImage(sender: UITapGestureRecognizer) {
        sender.view?.removeFromSuperview()
    }
    
    func handleRefresh(refreshControl: UIRefreshControl) {
        self.tableView.reloadData()
        refreshControl.endRefreshing()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 300
        
    }
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return selectedTableResource.categories.count
    }
    
    // There is just one row in every section
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedTableResource.categories[section].photos.count
    }
    
    
    // Set the spacing between sections
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return cellSpacingHeight
    }
    
    func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        let header:UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
        
        header.textLabel!.textColor = UIColor.whiteColor()
        header.textLabel!.font = UIFont.boldSystemFontOfSize(18)
        header.textLabel!.frame = header.frame
        header.backgroundView?.backgroundColor = UIColor.darkGrayColor()
        header.textLabel!.textAlignment = NSTextAlignment.Center
        header.textLabel!.text = selectedTableResource.categories[section].name
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! InfoCell
        let info = selectedTableResource.categories[indexPath.section].photos[indexPath.row]
        cell.detail.text = info.description
        cell.detail.lineBreakMode = NSLineBreakMode.ByWordWrapping
        cell.detailImage.image = info.image
        cell.selectionStyle = .None
        cell.backgroundColor = UIColor.darkGrayColor()
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let info = selectedTableResource.categories[indexPath.section].photos[indexPath.row]
        let newImageView = UIImageView(image: info.image)
        newImageView.frame = self.view.frame
        newImageView.backgroundColor = UIColor(red: 91/255, green: 113/255, blue: 62/255, alpha: 1)
        newImageView.contentMode = .ScaleAspectFit
        newImageView.userInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage(_:)))
        newImageView.addGestureRecognizer(tap)
        self.view.addSubview(newImageView)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func scrollToTop() {
        if (self.numberOfSectionsInTableView(self.tableView) > 0 ) {
            
            let top = NSIndexPath(forRow: Foundation.NSNotFound, inSection: 0);
            self.tableView.scrollToRowAtIndexPath(top, atScrollPosition: .Top, animated: true);
        }
    }
    
    
    
}
