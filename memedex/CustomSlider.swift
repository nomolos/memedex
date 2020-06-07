//
//  CustomSlider.swift
//  memedex
//
//  Created by meagh054 on 4/19/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit

class CustomSlider: UISlider {
    
    // Change this to make slider circle larger
    // Should eventually increase box size without larger icon
    @IBInspectable var thumbRadius: CGFloat = 50
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let thumb = thumbImage(radius: thumbRadius)
        setThumbImage(thumb, for: .normal)
    }
    
    @IBInspectable open var trackWidth:CGFloat = 2 {
        didSet {setNeedsDisplay()}
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
       var newBounds = super.trackRect(forBounds: bounds)
       newBounds.size.height = 15
       return newBounds
    }
    
    private func thumbImage(radius: CGFloat) -> UIImage {
        thumbView.frame = CGRect(x: 0, y: radius / 2, width: radius, height: radius)
        thumbView.layer.cornerRadius = radius / 2
        let renderer = UIGraphicsImageRenderer(bounds: thumbView.bounds)
        return renderer.image { rendererContext in
            thumbView.layer.render(in: rendererContext.cgContext)
        }
    }
    
    private lazy var thumbView: UIView = {
        let thumb = UIView()
        thumb.backgroundColor = UIColor.white
        thumb.layer.borderWidth = 0.4
        thumb.layer.borderColor = UIColor.darkGray.cgColor
        return thumb
    }()

}
