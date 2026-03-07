//
//  MaskView.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 8/3/26.
//

import UIKit

class MaskView: UIView {
    
    static let shared = MaskView()
    
    private init() {
        super.init(frame:UIScreen.main.bounds)
        
        self.frame = UIScreen.main.bounds
        self.backgroundColor = UIColor.lightGray
        self.layer.opacity = 0.5
        layer.masksToBounds = true
    
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(message: String, duration: TimeInterval = 2.0) {
        
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first else { return }
        
        if superview == nil {
            window.addSubview(self)
        }
        
        window.bringSubviewToFront(self)
        
    }
    
    func hide() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -50)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}

