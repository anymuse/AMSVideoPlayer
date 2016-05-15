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

@property (strong, nonatomic, readonly) AVPlayerLayer *playerLayer;

- (instancetype)initWithURL:(NSURL *)url containerViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
