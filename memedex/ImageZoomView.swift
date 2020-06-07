//
//  ImageZoomView.swift
//  memedex
//
//  Created by meagh054 on 5/29/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit

// This whole class exists for zooming into images
// Double tap to zoom is currently a little buggy -> doesn't take you
// exactly where you double tap
class ImageZoomView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var imageView: UIImageView!
    var gestureRecognizer: UITapGestureRecognizer!
    var zoomHere:CGPoint?
    var pinchGesture = UIPinchGestureRecognizer()

    
    convenience init(frame: CGRect, something:Bool) {
        self.init(frame: frame)
        self.frame = frame
        setupGestureRecognizer()
    }
    
    func getImage() -> UIImage {
        return self.imageView.image!
    }
    
    func updateImage(imageView: UIImageView){
        self.imageView = nil
        self.imageView = imageView
        self.imageView.contentMode = .scaleAspectFit
        self.addSubview(imageView)
        self.imageView.centerXAnchor.constraint(equalTo: self.contentLayoutGuide.centerXAnchor).isActive = true
        self.imageView.centerYAnchor.constraint(equalTo: self.contentLayoutGuide.centerYAnchor).isActive = true
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.setupScrollView(image: self.imageView.image!)
        self.removeConstraints(self.constraints)
        self.setNeedsLayout()
    }
    
    
    // Sets the scroll view delegate and zoom scale limits.
    // Change the `maximumZoomScale` to allow zooming more than 2x.
    func setupScrollView(image: UIImage) {
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 2.0
    }
    
    // Sets up the gesture recognizer that receives double taps to auto-zoom
    func setupGestureRecognizer() {
        gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        gestureRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(gestureRecognizer)
    }
    
    @IBAction func handleDoubleTap() {
        self.zoomHere = self.gestureRecognizer.location(in: self)
        if zoomScale == 1 {
            zoom(to: zoomRectForScale(maximumZoomScale, center: self.gestureRecognizer.location(in: self)), animated: true)
        } else {
            setZoomScale(1, animated: true)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        self.zoomHere = touch.location(in: self)
    }
    
    // Calculates the zoom rectangle for the scale
    func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.size.width = imageView.frame.size.width / scale
        let newCenter = self.zoomHere
        zoomRect.origin.x = newCenter!.x
        zoomRect.origin.y = newCenter!.y
        return zoomRect
    }
    
    // Tell the scroll view delegate which view to use for zooming and scrolling
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

}
