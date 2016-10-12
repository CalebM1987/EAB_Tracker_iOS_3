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
    let imageName: String
    
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

extension UIImage {
    func imageWithSize(size:CGSize) -> UIImage
    {
        var scaledImageRect = CGRect.zero;
        
        let aspectWidth:CGFloat = size.width / self.size.width;
        let aspectHeight:CGFloat = size.height / self.size.height;
        let aspectRatio:CGFloat = min(aspectWidth, aspectHeight);
        
        scaledImageRect.size.width = self.size.width * aspectRatio;
        scaledImageRect.size.height = self.size.height * aspectRatio;
        scaledImageRect.origin.x = (size.width - scaledImageRect.size.width) / 2.0;
        scaledImageRect.origin.y = (size.height - scaledImageRect.size.height) / 2.0;
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        
        self.drawInRect(scaledImageRect);
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return scaledImage!;
    }
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
                let image = UIImage(named: photo["image"]!)?.imageWithSize(defaultSize)
                /*
                let size = image?.size
                if size!.height < 125 {
                    let newSize = CGSize(width: size!.height * 1.1, height: size!.width * 1.1)
                    image = resizeImage(image!, toSize: newSize)
                }*/
                let imResource = ImageResource(image: image!, description: description, imageName: photo["image"]!)
                photos.append(imResource)
            }
            
            categories.append(Category(name: categoryName, photos: photos))
        }
    }
    return categories
}


