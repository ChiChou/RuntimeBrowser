//
//  main.swift
//  draw_history
//
//  Created by nst on 20/12/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

import Cocoa

let TOP_MARGIN_HEIGHT = 12
let RIGHT_MARGIN_WIDTH = 260
let LINE_HEIGHT = 12
let BOX_WIDTH = 32

func sortedVersions(d: [String:[VersionAndStatus]]) -> [String] {
    let allVersionAndStatuses : [[VersionAndStatus]] = [[VersionAndStatus]](d.values)
    let flattenedVersionsAndStatuses = Array(allVersionAndStatuses.flatten())
    let allVersions = flattenedVersionsAndStatuses.map { $0.version }
    let allVersionsUniqueSorted = Array(Set(allVersions)).sort()
    return allVersionsUniqueSorted
}

enum Status {
    case Public
    case Private
    case Lib
}

func status(s: String) -> Status? {
    switch s {
    case "pub":
        return .Public
    case "pri":
        return .Private
    case "lib":
        return .Lib
    default:
        return nil
    }
}

func matches(string s: String, pattern: String) throws -> [String] {
    
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let matches = regex.matchesInString(s, options: [], range: NSMakeRange(0, s.characters.count))
    
    var results = [String]()
    
    for index in 1..<matches[0].numberOfRanges {
        results.append((s as NSString).substringWithRange(matches[0].rangeAtIndex(index)))
    }
    
    return results
}

typealias VersionAndStatus = (version: String, status: Status)

func versionAndStatus(filename s: String) -> VersionAndStatus? {
    
    do {
        let results = try matches(string: s, pattern: "(\\d)_(\\d)_(\\S*)\\.txt")
        guard results.count == 3 else { return nil}
        
        let (major, minor, statusString) = (results[0], results[1], results[2])
        
        if let status = status(statusString) {
            return ("\(major).\(minor)", status)
        }
    } catch {
        print(error)
    }
    
    return nil
}

func buildDataDictionary(path:String) -> [String:[VersionAndStatus]]? {
        
    var d : [String:[VersionAndStatus]] = [:]
    
    do {
        let filenames = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path).filter{ $0.hasSuffix(".txt") }
        
        for filename in filenames {
            if let (version, status) = versionAndStatus(filename: filename) {
                
                let filepath = (path as NSString).stringByAppendingPathComponent(filename)
                let contents = try String(contentsOfFile: filepath, encoding: NSUTF8StringEncoding)
                contents.enumerateLines({ (symbol, stop) -> () in
                    
                    if(d[symbol] == nil) { d[symbol] = [] }
                    
                    d[symbol]!.append((version, status))
                })
            }
        }
        
    } catch {
        print(error)
        return nil
    }
    
    return d
}

func colorForStatus(status: Status) -> NSColor {
    switch status {
    case .Public:
        return NSColor(calibratedRed:0.0, green: 102.0/255.0, blue:0.0, alpha:1.0)
    case .Private:
        return NSColor.redColor()
    case .Lib:
        return NSColor.blueColor()
        //default:
        //    return NSColor.grayColor()
    }
}

private func saveAsPNGWithName(fileName: String, bitmap: NSBitmapImageRep) -> Bool {
    if let data = bitmap.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:]) {
        return data.writeToFile(fileName, atomically: false)
    }
    return false
}

private func drawIntoBitmap(bitmap: NSBitmapImageRep, data d:[String:[VersionAndStatus]] ) {
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    let cgContext : CGContextRef? = context?.CGContext
    
    NSGraphicsContext.setCurrentContext(context)
    
    CGContextSaveGState(cgContext)
    
    CGContextSetAllowsAntialiasing(cgContext, false)
    
    let textAttributes : [String : AnyObject] = [
        NSFontAttributeName: NSFont(name: "Monaco", size: 10.0)!,
        NSForegroundColorAttributeName: NSColor.blackColor()
    ]
    
    let sortedSymbols = Array(d.keys).sort()
    
    let versions = sortedVersions(d)
    
    NSColor.lightGrayColor().setFill()
    NSRectFill(CGRectMake(0, 0, bitmap.size.width, bitmap.size.height))
    
    for (i, s) in sortedSymbols.enumerate() {
        // draw symbols lines
        let x = CGFloat(versions.count * BOX_WIDTH + 3)
        let y = bitmap.size.height - CGFloat(2 * TOP_MARGIN_HEIGHT + i * LINE_HEIGHT)
        s.drawAtPoint(NSMakePoint(x, y), withAttributes:textAttributes)
        
        // fill boxes
        if let versionAndStatuses = d[s] {
            for (version, status) in versionAndStatuses {
                colorForStatus(status).setFill()
                
                let x1 = CGFloat(versions.indexOf(version)! * BOX_WIDTH) + 1
                let x2 = x1 + CGFloat(BOX_WIDTH) - 1
                let y1 = bitmap.size.height - CGFloat(2 * TOP_MARGIN_HEIGHT + i * LINE_HEIGHT - 1)
                let y2 = bitmap.size.height - CGFloat(2 * TOP_MARGIN_HEIGHT + (i+1) * LINE_HEIGHT - 2)
                
                let rect = CGRectMake(x1, y1, x2-x1, y1-y2)
                
                NSRectFill(rect)
            }
        }
    }
    
    // draw vertical separators
    var major : String = ""
    for (i, v) in versions.enumerate() {
        let current_major : String = v.componentsSeparatedByString(".")[0]
        if current_major != major {
            let p1 = CGPointMake(CGFloat(i * BOX_WIDTH), 0)
            let p2 = CGPointMake(CGFloat(i * BOX_WIDTH), CGFloat(d.count * LINE_HEIGHT + TOP_MARGIN_HEIGHT))
            NSBezierPath.strokeLineFromPoint(p1, toPoint: p2)
            
            major = current_major
        }
        // draw column headers
        v.drawAtPoint(NSMakePoint(CGFloat(i * BOX_WIDTH + 7), bitmap.size.height - CGFloat(TOP_MARGIN_HEIGHT)), withAttributes:textAttributes)
    }
    
    let p1 = CGPointMake(CGFloat(versions.count * BOX_WIDTH), bitmap.size.height)
    let p2 = CGPointMake(CGFloat(versions.count * BOX_WIDTH), bitmap.size.height - CGFloat(d.count * LINE_HEIGHT + TOP_MARGIN_HEIGHT))
    NSBezierPath.strokeLineFromPoint(p1, toPoint: p2)
    
    let p3 = CGPointMake(0, bitmap.size.height - CGFloat(TOP_MARGIN_HEIGHT))
    let p4 = CGPointMake(CGFloat(versions.count * BOX_WIDTH), bitmap.size.height - CGFloat(TOP_MARGIN_HEIGHT))
    NSBezierPath.strokeLineFromPoint(p3, toPoint: p4)
    
    CGContextRestoreGState(cgContext)
    
}

public func main() -> Int {
    
    let histoPath = NSUserDefaults.standardUserDefaults().valueForKey("data")
    guard let existingPathArg = histoPath as? String else {
        print("Usage: $ swift draw_history.swift -data path/to/data")
        return 1
    }
    
    let optionalDictionary = buildDataDictionary(existingPathArg)
    
    guard let d = optionalDictionary else {
        fatalError("Cannot build data")
    }
    
    let versions = sortedVersions(d)
    
    let WIDTH = CGFloat(versions.count * BOX_WIDTH + RIGHT_MARGIN_WIDTH)
    let HEIGHT = CGFloat(d.count * LINE_HEIGHT + TOP_MARGIN_HEIGHT)
    let SIZE = CGSize(width: WIDTH, height: HEIGHT)
    
    let optBitmapImageRep = NSBitmapImageRep(bitmapDataPlanes:nil,
        pixelsWide:Int(SIZE.width),
        pixelsHigh:Int(SIZE.height),
        bitsPerSample:8,
        samplesPerPixel:4,
        hasAlpha:true,
        isPlanar:false,
        colorSpaceName:NSDeviceRGBColorSpace,
        bytesPerRow:0,
        bitsPerPixel:0)
    
    guard let bitmap = optBitmapImageRep else { fatalError("can't create bitmap image rep") }
    
    drawIntoBitmap(bitmap, data:d)
    
    let currentPath : NSString = NSFileManager.defaultManager().currentDirectoryPath
    let outPath = currentPath.stringByAppendingPathComponent("ios_frameworks.png")
    let success = saveAsPNGWithName(outPath, bitmap:bitmap)
    
    if(success) {
        print("PNG written at", outPath)
    } else {
        print("cannot write PNG at", outPath)
    }
    
    return success ? 0 : 1
}

main()