//
//  AMSVideoPlayerView.m
//  AMSVideoPlayer
//
//  Created by 朱琨 on 16/5/15.
//  Copyright © 2016年 Talenton. All rights reserved.
//

#import "AMSVideoPlayerView.h"
#import <AVFoundation/AVFoundation.h>

@interface AMSVideoPlayerView ()

@property (weak, nonatomic) IBOutlet UISlider *videoTimeControl;
@property (copy, nonatomic) NSURL *url;

@property (assign, nonatomic) UIDeviceOrientation currentOrientation;
@property (weak, nonatomic) UIViewController *viewController;

@property (assign, nonatomic) CGRect originalFrame;


@end

@implementation AMSVideoPlayerView

#pragma mark - Init
- (instancetype)initWithURL:(NSURL *)url containerViewController:(nonnull UIViewController *)viewController {
    AMSVideoPlayerView *view = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([AMSVideoPlayerView class]) owner:nil options:nil].firstObject;
    if ([url isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    view.url = url;
    view.viewController = viewController;
    return view;
}

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

#pragma mark - Action
- (IBAction)didTapFullscreenButton:(UIButton *)sender {
    sender.selected = !sender.selected;
    
}

- (IBAction)didTapPlayButton:(UIButton *)sender {
    sender.selected = !sender.selected;
}

- (IBAction)didTapBackButton:(id)sender {
}

- (void)deviceOrientationDidChangeNotification {
    UIDeviceOrientation orienttation = [[UIDevice currentDevice] orientation];
    self.currentOrientation = orienttation;
}

#pragma mark - Getters & Setters
- (void)setCurrentOrientation:(UIDeviceOrientation)currentOrientation {
    if (_currentOrientation == currentOrientation || (currentOrientation != UIDeviceOrientationPortrait && !UIDeviceOrientationIsLandscape(currentOrientation))) {
        return;
    }
    _currentOrientation = currentOrientation;
    
    [[UIApplication sharedApplication] setStatusBarOrientation:(UIInterfaceOrientation)currentOrientation animated:YES];
    
    if (self.viewController.navigationController) {
        [self.viewController.navigationController setNavigationBarHidden:currentOrientation != UIDeviceOrientationPortrait animated:NO];
    }
    //    [[UIApplication sharedApplication] setStatusBarStyle:currentOrientation == UIDeviceOrientationPortrait ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent animated:YES];
    
    CGSize windowSize = [UIApplication sharedApplication].keyWindow.bounds.size;
    
    CGAffineTransform transform;
    if (currentOrientation == UIDeviceOrientationPortrait) {
        transform = CGAffineTransformIdentity;
    } else if (currentOrientation == UIDeviceOrientationLandscapeLeft) {
        transform = CGAffineTransformMakeRotation(M_PI_2);
    } else {
        transform = CGAffineTransformMakeRotation(-M_PI_2);
    }
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
        if (currentOrientation != UIDeviceOrientationPortrait) {
            self.bounds = CGRectMake(0, 0, windowSize.height, windowSize.width);
            self.center = CGPointMake(windowSize.width / 2, windowSize.height / 2);
        }
        
        self.transform = transform;
        
        if (currentOrientation == UIDeviceOrientationPortrait) {
            self.frame = self.originalFrame;
        }
    } completion:nil];
}

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)self.layer;
}

- (void)setPlayer:(AVPlayer*)player {
    [(AVPlayerLayer*)[self layer] setPlayer:player];
}

@end
