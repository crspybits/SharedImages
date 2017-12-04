//
//  NSDate+Extras.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 3/17/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

public extension Date {
    public enum TimeUnit {
        case day
        case week
        case month
        case year
    }
    
    // Any units other than those given are discarded in the returned date.
    // Note that units can be passed in an array style, e.g., [.Year, .Month, .Day]
    public func keepOnlyUnits(_ units:NSCalendar.Unit) -> Date {
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(units, from: self)
        return calendar.date(from: components)!
    }
    
    public func add(_ timeUnit:TimeUnit, amount:Int) -> Date {
        let calendar = Calendar.current
        var additionalDateComponent = DateComponents()
        
        switch timeUnit {
        case .day:
            additionalDateComponent.day = amount
            
        case .week:
            additionalDateComponent.weekOfYear = amount

        case .month:
            additionalDateComponent.month = amount

        case .year:
            additionalDateComponent.year = amount
        }

        return (calendar as NSCalendar).date(byAdding: additionalDateComponent, to: self, options: NSCalendar.Options(rawValue: 0))!
    }
}
