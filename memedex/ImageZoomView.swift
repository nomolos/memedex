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
    //var swipeGestureRecognizer: UISwipeGestureRecognizer!
    //var swipeGestureRecognizer2: UISwipeGestureRecognizer!
    var zoomHere:CGPoint?
    var pinchGesture = UIPinchGestureRecognizer()
    //var panGesture = UIPanGestureRecognizer?
    var panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePans))
    var ultimate_center:CGPoint?
    var ultimate_center_set = false
    static var slider_value:Float?
    
    convenience init(frame: CGRect, something:Bool) {
        self.init(frame: frame)
        self.frame = frame
        setupGestureRecognizer()
        //setupSwipeGestureRecognizer()
        setupPanGestureRecognizer()
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
        //self.ultimate_center = self.imageView.center
        print("printing ultimate center in update image")
        print(self.ultimate_center)
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
    
    /*func setupSwipeGestureRecognizer() {
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
    }*/
    
    func setupPanGestureRecognizer() {
        self.panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePans))
        addGestureRecognizer(self.panGesture)
        //let image =
    }
    
    /*@IBAction func handleSwipe() {
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
    }*/
    
    /*@IBAction func handleSwipe2() {
        let nc = NotificationCenter.default
        nc.post(name: NSNotification.Name(rawValue: "back"), object: nil)
        print("done in handleSwipe2")
    }*/
    
    @objc func handlePans() {
        if(!ultimate_center_set){
            self.ultimate_center = self.imageView.center
            self.ultimate_center_set = true
        }
        //print("printing image center in handle pans")
        //print(self.imageView.center)
        //let temp_center = self.imageView.center
        print("printing temp center 1")
        //print(temp_center)
        let square = self.imageView!
        //print("printing superview")
        //print(self.superview)
        // Could be problematic that temp center is set every single time
        if(!(self.panGesture.state == UIGestureRecognizer.State.ended)){
            print("not in ended")
            // point is currently defined within the ImageZoomView, not the overall view
            
            //let point = self.panGesture.translation(in: self)
            let point = self.panGesture.location(in: self.superview)
            let divisor = (self.superview!.frame.width/2)/0.61
            square.center.x = /*self.imageView.center.x +*/ point.x
            //square.center = CGPoint(x: self.imageView.center.x + (point.x/6), y: self.imageView.center.y + (point.y/6))
            
            print("printing square center x")
            print(square.center.x)
            print("printing point.x")
            print(point.x)
            
            //550, 200, 0
            
            
            //ImageZoomView.slider_value = Float((point.x+35)/13)
            ImageZoomView.slider_value = Float(square.center.x/60)
            
            let nc = NotificationCenter.default
            nc.post(name: NSNotification.Name(rawValue: "update_slider"), object: nil)
            // (x + 40)/13
            let xFromCenter = square.center.x - self.ultimate_center!.x
            print("printing xFromCenter")
            print(xFromCenter)
            let scale = min(50/abs(xFromCenter), 1)
            //print(temp_center)
            square.transform = CGAffineTransform(rotationAngle: xFromCenter/divisor).scaledBy(x: scale, y: scale)
        }
        else if self.panGesture.state == UIGestureRecognizer.State.ended{
            print("in ended")
            //let square = self.imageView!
            square.transform = CGAffineTransform.identity
            /*if(square.center.x < 50){
                print("shouldswipe")
                let nc = NotificationCenter.default
                nc.post(name: NSNotification.Name(rawValue: "next"), object: nil)
                self.ultimate_center_set = false
            }
            else if(square.center.x > self.imageView.frame.width - 20){
                print("shouldswipe")
                let nc = NotificationCenter.default
                nc.post(name: NSNotification.Name(rawValue: "next"), object: nil)
                self.ultimate_center_set = false
            }*/
            /*UIView.animate(withDuration: 0.2, animations: {
                square.center = temp_center
                self.setNeedsDisplay()
            })*/
            //square.center = temp_center
            //print("printing temp center 3")
            //print(temp_center)
            /*UIView.animate(withDuration: 0.2, animations: {
                square.center = self.ultimate_center!
                self.setNeedsDisplay()
            })*/
            let nc = NotificationCenter.default
            nc.post(name: NSNotification.Name(rawValue: "next"), object: nil)
            self.ultimate_center_set = false
        }
        //else if self.panGesture.state == UIGestureRecognizer.State.
        /*UIView.animate(withDuration: 0.2, animations: {
            square.center = temp_center
            self.setNeedsDisplay()
        })*/
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

/*extension UIImageView {
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

}*/
