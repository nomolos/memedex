//
//  TextField.swift
//  memedex
//
//  Created by meagh054 on 4/11/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit

// Use this because we want some indent in our text fields
// (It's prettier)
class TextField: UITextField {

    let padding = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)

    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }

    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }

    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}
