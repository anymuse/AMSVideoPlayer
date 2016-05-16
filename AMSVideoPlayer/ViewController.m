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
@property (strong, nonatomic) UIView *buttonView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.playerView = [[AMSVideoPlayerView alloc] initWithContainerViewController:self];
    self.playerView.frame = CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width * 9 / 16);
    self.playerView.layer.backgroundColor = [UIColor redColor].CGColor;
    [self.view addSubview:self.playerView];
    
    self.buttonView = [UIView new];
    self.buttonView.backgroundColor = [UIColor greenColor];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button addTarget:self action:@selector(loadVideo) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:@"加载视频" forState:UIControlStateNormal];
    [self.buttonView addSubview:button];
    [self.playerView addSubview:self.buttonView];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.buttonView);
    }];
    
    [self.buttonView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.playerView);
    }];
    
    
}

- (void)loadVideo {
    [self.buttonView removeFromSuperview];
    [self.playerView playVideoWithURL:[NSURL URLWithString:@"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4"]];
}

- (BOOL)prefersStatusBarHidden {
    return self.playerView.prefersStatusBarHidden;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (self.playerView.isLandscape) {
        return UIStatusBarStyleLightContent;
    }
    return UIStatusBarStyleDefault;
}

@end
