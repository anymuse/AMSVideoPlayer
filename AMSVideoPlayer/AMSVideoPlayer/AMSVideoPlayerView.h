//
//  AMSVideoPlayerView.h
//  AMSVideoPlayer
//
//  Created by 朱琨 on 16/5/15.
//  Copyright © 2016年 Talenton. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVPlayerLayer;

NS_ASSUME_NONNULL_BEGIN

@interface AMSVideoPlayerView : UIView

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic, readonly) AVPlayerLayer *playerLayer;

- (instancetype)initWithContainerViewController:(UIViewController *)viewController;

- (void)playVideoWithURL:(NSURL *)url;

- (BOOL)isLandscape;
- (BOOL)prefersStatusBarHidden;

@end

NS_ASSUME_NONNULL_END
