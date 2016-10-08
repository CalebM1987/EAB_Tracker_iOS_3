//
//  EABInfo.swift
//  EAB_Tracker
//
//  Created by Caleb Mackey on 5/11/16.
//  Copyright © 2016 Caleb Mackey. All rights reserved.
//
import UIKit

var eabInfoList = [[NSLocalizedString("beetle_info", comment:""), "adult_beetle.png"],
                   [NSLocalizedString("larvae_info", comment:""), "larvae.png"],
                   [NSLocalizedString("bark_info", comment:""), "ash_vertical_split.png"],
                   [NSLocalizedString("exit_hole", comment:""), "exit_hole.png"],
                   [NSLocalizedString("s_gallary", comment:""), "s_gallery.png"]]

var defaultSize = CGSize(width: 300, height: 250)

class EABInfo: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    let cellIdentifier = "eabCell"
    let cellSpacingHeight: CGFloat = 20
    
    @IBAction func goBackToMap(sender: AnyObject) {
        tabBar.selectedIndex = 0
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.rowHeight = 300.0
        
    }
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return eabInfoList.count
    }
    
    // There is just one row in every section
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    // Set the spacing between sections
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return cellSpacingHeight
    }
    
    // Make the background color show through
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clearColor()
        return headerView
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCellWithIdentifier(cellIdentifier)! as UITableViewCell
        let info = eabInfoList[indexPath.section]
        cell.textLabel?.text = info[0]
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = NSLineBreakMode.ByWordWrapping
        cell.imageView?.image = resizeImage(UIImage(named: info[1])!, toSize: defaultSize)
        cell.backgroundColor = UIColor.darkGrayColor()
        cell.textLabel?.textColor = UIColor.whiteColor()
        
        return cell
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func resizeImage(image: UIImage, toSize newSize: CGSize) -> UIImage {
        let newRect = CGRectIntegral(CGRectMake(0,0, newSize.width, newSize.height))
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        let context = UIGraphicsGetCurrentContext()
        CGContextSetInterpolationQuality(context!, .High)
        let flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height)
        CGContextConcatCTM(context!, flipVertical)
        CGContextDrawImage(context!, newRect, image.CGImage!)
        let newImage = UIImage(CGImage: CGBitmapContextCreateImage(context!)!)
        UIGraphicsEndImageContext()
        return newImage
    }
    
    
}
