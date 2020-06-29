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
    var swipeGestureRecognizer: UISwipeGestureRecognizer!
    var swipeGestureRecognizer2: UISwipeGestureRecognizer!
    var zoomHere:CGPoint?
    var pinchGesture = UIPinchGestureRecognizer()

    
    convenience init(frame: CGRect, something:Bool) {
        self.init(frame: frame)
        self.frame = frame
        setupGestureRecognizer()
        setupSwipeGestureRecognizer()
    }
    
    func getImage() -> UIImage {
        return self.imageView.image!
    }
    
    func updateImage(imageView: UIImageView){
        self.isScrollEnabled = false
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
    
    func setupSwipeGestureRecognizer() {
        print("Adding swipe gesture recognizer")
        swipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe))
        swipeGestureRecognizer.direction = UISwipeGestureRecognizer.Direction.left
        swipeGestureRecognizer.delaysTouchesBegan = true
        swipeGestureRecognizer2 = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe2))
        swipeGestureRecognizer2.direction = UISwipeGestureRecognizer.Direction.right
        swipeGestureRecognizer.delaysTouchesBegan = true
        addGestureRecognizer(swipeGestureRecognizer)
        addGestureRecognizer(swipeGestureRecognizer2)
        self.panGestureRecognizer.require(toFail: swipeGestureRecognizer!)
        self.panGestureRecognizer.require(toFail: swipeGestureRecognizer2!)
    }
    
    @IBAction func handleSwipe() {
        print("inside handleSwipe")
        //let storyboard = UIStoryboard(name: "Main", bundle: nil)
        //let viewController = storyboard.instantiateViewController(identifier: "ViewController") as ViewController
        //viewController.next(self)
        let nc = NotificationCenter.default
        nc.post(name: NSNotification.Name(rawValue: "next"), object: nil)
        print("done in handleSwipe")
        //self.viewController?.
        //print(self.superview?.superview)
        //print(self.delegate)
    }
    
    @IBAction func handleSwipe2() {
        let nc = NotificationCenter.default
        nc.post(name: NSNotification.Name(rawValue: "back"), object: nil)
        print("done in handleSwipe2")
    }
    
    @IBAction func handleDoubleTap() {
        print("inside handle double tap")
        self.zoomHere = self.gestureRecognizer.location(in: self)
        if zoomScale == 1 {
            zoom(to: zoomRectForScale(maximumZoomScale, center: self.gestureRecognizer.location(in: self)), animated: true)
            self.isScrollEnabled = true
        } else {
            setZoomScale(1, animated: true)
            self.isScrollEnabled = false
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

extension UIImageView {
    // Name this function in a way that makes sense to you...
    // slideFromLeft, slideRight, slideLeftToRight, etc. are great alternative names
    func slideInFromRight(duration: TimeInterval = 0.3, completionDelegate: AnyObject? = nil) {
        // Create a CATransition animation
        let slideInFromRightTransition = CATransition()
        // Set its callback delegate to the completionDelegate that was provided (if any)
        if let delegate: AnyObject = completionDelegate {
            slideInFromRightTransition.delegate = delegate as! CAAnimationDelegate
        }
        
        // Customize the animation's properties
        slideInFromRightTransition.type = CATransitionType.push
        slideInFromRightTransition.subtype = CATransitionSubtype.fromRight
        slideInFromRightTransition.duration = duration
        slideInFromRightTransition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        slideInFromRightTransition.fillMode = CAMediaTimingFillMode.removed

        // Add the animation to the View's layer
        self.layer.add(slideInFromRightTransition, forKey: "slideInFromRightTransition")
    }
    
    func slideInFromLeft(duration: TimeInterval = 0.3, completionDelegate: AnyObject? = nil) {
        // Create a CATransition animation
        let slideInFromLeftTransition = CATransition()
        // Set its callback delegate to the completionDelegate that was provided (if any)
        if let delegate: AnyObject = completionDelegate {
            slideInFromLeftTransition.delegate = delegate as! CAAnimationDelegate
        }
        
        // Customize the animation's properties
        slideInFromLeftTransition.type = CATransitionType.push
        slideInFromLeftTransition.subtype = CATransitionSubtype.fromLeft
        slideInFromLeftTransition.duration = duration
        slideInFromLeftTransition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        slideInFromLeftTransition.fillMode = CAMediaTimingFillMode.removed

        // Add the animation to the View's layer
        self.layer.add(slideInFromLeftTransition, forKey: "slideInFromLeftTransition")
    }

}
