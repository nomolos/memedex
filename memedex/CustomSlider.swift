//
//  CustomSlider.swift
//  memedex
//
//  Created by meagh054 on 4/19/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit

class CustomSlider: UISlider {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
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
        // Set proper frame
        // y: radius / 2 will correctly offset the thumb

        thumbView.frame = CGRect(x: 0, y: radius / 2, width: radius, height: radius)
        thumbView.layer.cornerRadius = radius / 2

        // Convert thumbView to UIImage
        // See this: https://stackoverflow.com/a/41288197/7235585

        let renderer = UIGraphicsImageRenderer(bounds: thumbView.bounds)
        return renderer.image { rendererContext in
            thumbView.layer.render(in: rendererContext.cgContext)
        }
    }
    
    private lazy var thumbView: UIView = {
        let thumb = UIView()
        thumb.backgroundColor = UIColor.white//thumbTintColor
        thumb.layer.borderWidth = 0.4
        thumb.layer.borderColor = UIColor.darkGray.cgColor
        return thumb
    }()

}
