//
//  AMSVideoPlayerView+Rotation.m
//  AMSVideoPlayer
//
//  Created by 朱琨 on 16/5/16.
//  Copyright © 2016年 Talenton. All rights reserved.
//

#import "AMSVideoPlayerView+Rotation.h"

@interface AMSVideoPlayerView ()

@property (assign, nonatomic) UIDeviceOrientation currentOrientation;
@property (assign, nonatomic) BOOL prefersStatusBarHidden;
@property (assign, nonatomic) BOOL readyToPlay;
@property (assign, nonatomic) CGRect originalFrame;
@property (weak, nonatomic) UIButton *fullscreenButton;
@property (weak, nonatomic) UIView *bottomToolBarView;
@property (weak, nonatomic) UIView *topToolBarView;
@property (weak, nonatomic) UIViewController *viewController;

@end

@implementation AMSVideoPlayerView (Rotation)


- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview) {
        self.originalFrame = self.frame;
        if (!self.superview) {
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChangeNotification) name:UIDeviceOrientationDidChangeNotification object:nil];
        }
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    }
}

- (void)deviceOrientationDidChangeNotification {
    UIDeviceOrientation orienttation = [[UIDevice currentDevice] orientation];
    self.currentOrientation = orienttation;
}

- (void)transfromWithOrientation:(UIDeviceOrientation)orientation {
    [[UIApplication sharedApplication] setStatusBarOrientation:(UIInterfaceOrientation)orientation animated:YES];
    
    if (self.viewController.navigationController) {
        [self.viewController.navigationController setNavigationBarHidden:orientation != UIDeviceOrientationPortrait animated:NO];
    }
    
    CGSize windowSize = [UIApplication sharedApplication].keyWindow.bounds.size;
    
    CGAffineTransform transform;
    if (orientation == UIDeviceOrientationPortrait) {
        transform = CGAffineTransformIdentity;
    } else if (orientation == UIDeviceOrientationLandscapeLeft) {
        transform = CGAffineTransformMakeRotation(M_PI_2);
    } else {
        transform = CGAffineTransformMakeRotation(-M_PI_2);
    }
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
        if (orientation != UIDeviceOrientationPortrait) {
            if (self.bottomToolBarView.alpha == 0) {
                self.prefersStatusBarHidden = YES;
                [self.viewController setNeedsStatusBarAppearanceUpdate];
            }
            self.topToolBarView.hidden = NO;
            self.bounds = CGRectMake(0, 0, windowSize.height, windowSize.width);
            self.center = CGPointMake(windowSize.width / 2, windowSize.height / 2);
        }
        
        self.transform = transform;
        
        if (orientation == UIDeviceOrientationPortrait) {
            self.prefersStatusBarHidden = NO;
            [self.viewController setNeedsStatusBarAppearanceUpdate];
            self.topToolBarView.hidden = YES;
            self.frame = self.originalFrame;
        }
    } completion:^(BOOL finished) {
        self.fullscreenButton.selected = orientation != UIDeviceOrientationPortrait;
    }];
}

@end
