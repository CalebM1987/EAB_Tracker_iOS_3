//
//  ImageResources.swift
//  EAB_Tracker
//
//  Created by Caleb Mackey on 10/9/16.
//  Copyright © 2016 Caleb Mackey. All rights reserved.
//
import UIKit

var eabTableResource: TableResource!
var ashTableResource: TableResource!

struct ImageResource {
    let image: UIImage
    let description: String
}

struct Category {
    let name: String
    let photos: [ImageResource]
}

struct TableResource {
    let type: String
    var categories: [Category]
    
    init(type: String, categories: [Category]) {
        self.type = type
        self.categories = categories
    }
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


func tableCategoriesFromBundle(type: String) -> [Category] {
    var categories = [Category]()

    var rootObject: [String:AnyObject]!
    let fileManager = NSFileManager.defaultManager()
    let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0])
    let destinationJson = documentsPath.URLByAppendingPathComponent(type + ".json")!
    let sourceJsonURL = NSBundle.mainBundle().URLForResource(type, withExtension: "json")!
    
    if !fileManager.fileExistsAtPath(destinationJson.path!) {
        do {
            try fileManager.copyItemAtURL(sourceJsonURL, toURL: destinationJson)
        } catch let error as NSError {
            print("Unable to copy json file \(error.debugDescription)")
        }
    }

    // parse JSON into table resource
    do {
        let data = try NSData(contentsOfURL: destinationJson)
        rootObject = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions()) as? [String : AnyObject]
    }  catch {
        return categories
    }

    guard let categoryObjects = rootObject!["categories"] as? [[String: AnyObject]] else {
        print("Could not find Categories in JSON")
        return categories
    }
    
    for catObject in categoryObjects {
        var categoryName: String
        if let name = catObject["name"] as? String {
            categoryName = name
            let photosObject = catObject["photos"] as? [[String:String]]
            var photos = [ImageResource]()
            for photo in photosObject! {
                let description = photo["description"]!
                let image = UIImage(named: photo["image"]!)
                /*
                let size = image?.size
                if size!.height < 125 {
                    let newSize = CGSize(width: size!.height * 1.1, height: size!.width * 1.1)
                    image = resizeImage(image!, toSize: newSize)
                }*/
                let imResource = ImageResource(image: image!, description: description)
                photos.append(imResource)
            }
            
            categories.append(Category(name: categoryName, photos: photos))
        }
    }
    return categories
}


