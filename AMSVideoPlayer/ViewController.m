//
//  ViewController.m
//  AMSVideoPlayer
//
//  Created by 朱琨 on 16/5/14.
//  Copyright © 2016年 Talenton. All rights reserved.
//

#import "ViewController.h"
#import <Masonry.h>
#import "AMSVideoPlayerView.h"

@interface ViewController ()

@property (strong, nonatomic) AMSVideoPlayerView *playerView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.playerView = [[AMSVideoPlayerView alloc] initWithURL:[NSURL URLWithString:@""] containerViewController:self];
    self.playerView.frame = CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width * 9 / 16);
    self.playerView.layer.backgroundColor = [UIColor redColor].CGColor;
    [self.view addSubview:self.playerView];
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if ([UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
        return UIStatusBarStyleLightContent;
    }
    return UIStatusBarStyleDefault;
}

@end
