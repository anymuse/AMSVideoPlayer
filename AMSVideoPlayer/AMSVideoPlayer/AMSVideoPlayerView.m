//
//  AMSVideoPlayerView.m
//  AMSVideoPlayer
//
//  Created by 朱琨 on 16/5/15.
//  Copyright © 2016年 Talenton. All rights reserved.
//

#import "AMSVideoPlayerView.h"
#import "AMSVideoPlayerView+Rotation.h"
#import <AVFoundation/AVFoundation.h>

#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

static void *AMSVideoPlayerTimedMetadataObserverContext = &AMSVideoPlayerTimedMetadataObserverContext;
static void *AMSVideoPlayerRateObservationContext = &AMSVideoPlayerRateObservationContext;
static void *AMSVideoPlayerCurrentItemObservationContext = &AMSVideoPlayerCurrentItemObservationContext;
static void *AMSVideoPlayerPlayerItemStatusObserverContext = &AMSVideoPlayerPlayerItemStatusObserverContext;

static CGFloat const kAlphaOfToolBarView = 0.8;

static NSString * const kTracksKey		= @"tracks";
static NSString * const kStatusKey		= @"status";
static NSString * const kRateKey			= @"rate";
static NSString * const kPlayableKey		= @"playable";
static NSString * const kCurrentItemKey	= @"currentItem";
static NSString * const kTimedMetadataKey	= @"currentItem.timedMetadata";

@interface AMSVideoPlayerView ()

@property (assign, nonatomic) BOOL prefersStatusBarHidden;
@property (assign, nonatomic) BOOL readyToPlay;
@property (assign, nonatomic) BOOL seekToZeroBeforePlay;
@property (assign, nonatomic) BOOL pausedByUser;
@property (assign, nonatomic) CGRect originalFrame;
@property (assign, nonatomic) UIDeviceOrientation currentOrientation;
@property (strong, nonatomic) AVPlayer *player;;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) NSTimer *toolBarsInactiveTimer;
@property (strong, nonatomic) id timeObserver;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (weak, nonatomic) IBOutlet UIButton *fullscreenButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;
@property (weak, nonatomic) IBOutlet UISlider *videoTimeControl;
@property (weak, nonatomic) IBOutlet UIView *bottomToolBarView;
@property (weak, nonatomic) IBOutlet UIView *topToolBarView;
@property (weak, nonatomic) UIViewController *viewController;

- (BOOL)isPlaying;

@end

@implementation AMSVideoPlayerView

#pragma mark - Init
- (instancetype)initWithContainerViewController:(nonnull UIViewController *)viewController {
    AMSVideoPlayerView *view = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([AMSVideoPlayerView class]) owner:nil options:nil].firstObject;
    view.viewController = viewController;
    return view;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [self.player removeObserver:self forKeyPath:kCurrentItemKey];
    [self.player removeObserver:self forKeyPath:kTimedMetadataKey];
    [self.player removeObserver:self forKeyPath:kRateKey];
    [self.playerItem removeObserver:self forKeyPath:kStatusKey];
    [self removePlayerTimeObserver];
    [self.player pause];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

#pragma mark - Action
- (IBAction)didTapFullscreenButton:(UIButton *)sender {
    sender.selected = !sender.selected;
    self.currentOrientation = sender.selected ? UIDeviceOrientationLandscapeLeft : UIDeviceOrientationPortrait;
}

- (IBAction)didTapPlayButton:(UIButton *)sender {
    if (sender) {
        sender.selected = !sender.selected;
        /* If we are at the end of the movie, we must seek to the beginning first
         before starting playback. */
        if (sender.selected) {
            if (self.seekToZeroBeforePlay) {
                self.seekToZeroBeforePlay = NO;
                [self.player seekToTime:kCMTimeZero];
            }
            [self.player play];
        } else {
            [self.player pause];
            self.pausedByUser = YES;
        }
    } else {
        [self.player pause];
    }
}

- (IBAction)didTapBackButton:(id)sender {
}

- (IBAction)beginScrubbing:(id)sender {
    [self.toolBarsInactiveTimer invalidate];
    self.toolBarsInactiveTimer = nil;
    
    [self.player pause];
    
    /* Remove previous timer. */
    [self removePlayerTimeObserver];
}

- (IBAction)endScrubbing:(id)sender {
    if (!self.timeObserver) {
        [self addTimeObserver];
        [self.player play];
    }
}

- (IBAction)scrub:(id)sender {
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)) {
        float minValue = self.videoTimeControl.minimumValue;
        float maxValue = self.videoTimeControl.maximumValue;
        float value = self.videoTimeControl.value;
        
        double time = duration * (value - minValue) / (maxValue - minValue);
        CMTime currentTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
        [self.player seekToTime:currentTime];
        [self updateCurrentTimeLabelWithTime:currentTime];
    }
}

#pragma mark - Tool Bar
- (void)showToolBarsView:(BOOL)show {
    // Clear any pending actions.
    [self.toolBarsInactiveTimer invalidate];
    self.toolBarsInactiveTimer = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        if (show) {
            // Fade the ToolBarView into view by affecting its alpha.
            self.bottomToolBarView.alpha = kAlphaOfToolBarView;
            self.topToolBarView.alpha = kAlphaOfToolBarView;
            
            // Start the timeout timer for automatically hiding ToolBarView
            [self setToolBarsInactiveTimerWithTimeInterval:5];
        } else {
            // Fade the ToolBarView out of view by affecting its alpha.
            self.bottomToolBarView.alpha = 0;
            self.topToolBarView.alpha = 0;
        }
        
        if (self.isLandscape) {
            self.prefersStatusBarHidden = !show;
            [self.viewController setNeedsStatusBarAppearanceUpdate];
        }
    }];
}

- (void)hideToolBars {
    self.topToolBarView.hidden = YES;
    self.bottomToolBarView.hidden = YES;
}

- (void)timerFired:(NSTimer *)timer {
    if (timer == self.toolBarsInactiveTimer) {
        if (self.bottomToolBarView.alpha == 0) {
            return;
        }
        // Time has passed, hide the ToolBarView.
        [self showToolBarsView:NO];
    }
}

- (void)setLoadingViewHidden:(BOOL)hidden {
    self.loadingLabel.hidden = hidden;
    self.loadingIndicator.hidden = hidden;
    hidden ? [self.loadingIndicator stopAnimating] : [self.loadingIndicator startAnimating];
}

#pragma mark - Public Method
- (void)playVideoWithURL:(NSURL *)url {
    //    /* Make sure that the value of each key has loaded successfully. */
    //    for (NSString *thisKey in requestedKeys) {
    //        NSError *error = nil;
    //        AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
    //        if (keyStatus == AVKeyValueStatusFailed) {
    //            [self assetFailedToPrepareForPlayback:error];
    //            return;
    //        }
    //        /* If you are also implementing the use of -[AVAsset cancelLoading], add your code here to bail
    //         out properly in the case of cancellation. */
    //    }
    //
    //    /* Use the AVAsset playable property to detect whether the asset can be played. */
    //    if (!asset.playable) {
    //        /* Generate an error describing the failure. */
    //        NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
    //        NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
    //        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
    //                                   localizedDescription, NSLocalizedDescriptionKey,
    //                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
    //                                   nil];
    //        NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
    //
    //        /* Display the error to the user. */
    //        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
    //
    //        return;
    //    }
    //
    
    [self setLoadingViewHidden:NO];
    /* At this point we're ready to set up for playback of the asset. */
    [self initScrubberTimer];
    //    [self enableScrubber];
    //    [self enablePlayerButtons];
    
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.playerItem) {
        /* Remove existing player item key value observers and notifications. */
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
    
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.playerItem = [AVPlayerItem playerItemWithURL:url];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.playerItem addObserver:self
                      forKeyPath:kStatusKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AMSVideoPlayerPlayerItemStatusObserverContext];
    
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
    
    self.seekToZeroBeforePlay = NO;
    
    /* Create new player, if we don't already have one. */
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:self.player];
        
        /* Observe the AVPlayer "currentItem" property to find out when any
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did
         occur.*/
        [self.player addObserver:self
                      forKeyPath:kCurrentItemKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AMSVideoPlayerCurrentItemObservationContext];
        
        /* A 'currentItem.timedMetadata' property observer to parse the media stream timed metadata. */
        [self.player addObserver:self
                      forKeyPath:kTimedMetadataKey
                         options:0
                         context:AMSVideoPlayerTimedMetadataObserverContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self
                      forKeyPath:kRateKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AMSVideoPlayerRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.playerItem) {
        /* Replace the player item with a new player item. The item replacement occurs
         asynchronously; observe the currentItem property to find out when the
         replacement will/did occur*/
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        [self syncPlayButton];
    }
    
    [self.videoTimeControl setValue:0.0];
    [self.player play];
}

- (void)pause {
    [self didTapPlayButton:nil];
}

-(void)assetFailedToPrepareForPlayback:(NSError *)error {
    [self removePlayerTimeObserver];
    [self syncScrubber];
}

#pragma mark - Private Method
- (void)addTimeObserver {
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)) {
        @weakify(self)
        self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:
                             ^(CMTime time) {
                                 @strongify(self)
                                 [self syncScrubber];
                                 [self updateCurrentTimeLabelWithTime:time];
                             }];
    }
}

- (void)invalidateTimer:(NSTimer *)timer {
    [timer invalidate];
    timer = nil;
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayButton {
    self.playButton.selected = self.isPlaying;
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver {
    if (self.timeObserver) {
        [self.player removeTimeObserver:_timeObserver];
        self.timeObserver = nil;
    }
}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber {
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        self.videoTimeControl.minimumValue = 0.0;
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration) && (duration > 0)) {
        float minValue = self.videoTimeControl.minimumValue;
        float maxValue = self.videoTimeControl.maximumValue;
        double time = CMTimeGetSeconds(self.playerItem.currentTime);
        [self.videoTimeControl setValue:(maxValue - minValue) * time / duration + minValue];
    }
}

/* Requests invocation of a given block during media playback to update the
 movie scrubber control. */
-(void)initScrubberTimer {
    double duration = CMTimeGetSeconds([self playerItemDuration]);
    [self updateDurationTimeLabelWithDuration:duration];
    [self addTimeObserver];
}

- (void)updateDurationTimeLabelWithDuration:(double)duration {
    NSUInteger minutesOfDuration = (NSUInteger)duration / 60;
    NSUInteger secondsOfDuration = (NSUInteger)duration % 60;
    self.durationTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (unsigned long)minutesOfDuration, (unsigned long)secondsOfDuration];
}

- (void)updateCurrentTimeLabelWithTime:(CMTime)time {
    Float64 currentTime = CMTimeGetSeconds(time);
    NSUInteger minutesOfCurrentTime = (NSUInteger)currentTime / 60;
    NSUInteger secondsOfCurrentTime = (NSUInteger)currentTime % 60;
    self.currentTimeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (unsigned long)minutesOfCurrentTime, (unsigned long)secondsOfCurrentTime];
}

#pragma mark - Player Notifications
/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification {
    /* After the movie has played to its end time, seek back to time zero
     to play it again */
    self.seekToZeroBeforePlay = YES;
}



#pragma mark Key Value Observer for player rate, currentItem, player item status

/* ---------------------------------------------------------
 **  Called when the value at the specified key path relative
 **  to the given object has changed.
 **  Adjust the movie play and pause button controls when the
 **  player item "status" value changes. Update the movie
 **  scrubber control when the player item is ready to play.
 **  Adjust the movie scrubber control when the player item
 **  "rate" value changes. For updates of the player
 **  "currentItem" property, set the AVPlayer for which the
 **  player layer displays visual output.
 **  NOTE: this method is invoked on the main queue.
 ** ------------------------------------------------------- */

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
    /* AVPlayerItem "status" property value observer. */
    if (context == AMSVideoPlayerPlayerItemStatusObserverContext) {
        [self syncPlayButton];
        
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
                /* Indicates that the status of the player is not yet known because
                 it has not tried to load new media resources for playback */
            case AVPlayerItemStatusUnknown: {
                [self removePlayerTimeObserver];
                [self syncScrubber];
                self.readyToPlay = NO;
            } break;
                
            case AVPlayerItemStatusReadyToPlay: {
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                self.readyToPlay = YES;
                self.playerLayer.backgroundColor = [[UIColor blackColor] CGColor];
                
                /* Set the AVPlayerLayer on the view to allow the AVPlayer object to display
                 its content. */
                [self.playerLayer setPlayer:self.player];
                self.bottomToolBarView.hidden = NO;
                [self setLoadingViewHidden:YES];
                [self initScrubberTimer];
            } break;
            case AVPlayerItemStatusFailed: {
                self.readyToPlay = NO;
                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
            } break;
        }
    } else if (context == AMSVideoPlayerRateObservationContext) {
        /* AVPlayer "rate" property value observer. */
        [self syncPlayButton];
    } else if (context == AMSVideoPlayerCurrentItemObservationContext) {
        /* AVPlayer "currentItem" property observer.
         Called when the AVPlayer replaceCurrentItemWithPlayerItem:
         replacement will/did occur. */
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        /* New player item null? */
        if (newPlayerItem == (id)[NSNull null]) {
            //            [self disablePlayerButtons];
            //            [self disableScrubber];
            //
            //            self.isPlayingAdText.text = @"";
        } else {
            /* Replacement of player currentItem has occurred */
            /* Set the AVPlayer for which the player layer displays visual output. */
            [self.playerLayer setPlayer:self.player];
            /* Specifies that the player should preserve the video’s aspect ratio and
             fit the video within the layer’s bounds. */
            [self setVideoFillMode:AVLayerVideoGravityResizeAspect];
            [self syncPlayButton];
        }
    } else if (context == AMSVideoPlayerTimedMetadataObserverContext) {
        /* Observe the AVPlayer "currentItem.timedMetadata" property to parse the media stream
         timed metadata. */
        //        NSArray* array = self.playerItem.timedMetadata;
        //        for (AVMetadataItem *metadataItem in array) {
        //            [self handleTimedMetadata:metadataItem];
        //        }
    } else {
        [super observeValueForKeyPath:path ofObject:object change:change context:context];
    }
    
    return;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.toolBarsInactiveTimer invalidate];
    self.toolBarsInactiveTimer = nil;
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (touches.anyObject.tapCount > 0) {
        if (self.bottomToolBarView.alpha == 0) {
            [self showToolBarsView:YES];
        } else if (fabs(self.bottomToolBarView.alpha - kAlphaOfToolBarView) < 0.0001) {
            [self showToolBarsView:NO];
        }
    } else {
        if (!self.toolBarsInactiveTimer) {
            [self setToolBarsInactiveTimerWithTimeInterval:3];
        }
    }
    [super touchesEnded:touches withEvent:event];
}

#pragma mark - Getters & Setters
+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)self.layer;
}

- (void)setPlayer:(AVPlayer*)player {
    _player = player;
    [(AVPlayerLayer*)[self layer] setPlayer:player];
}

- (void)setVideoFillMode:(NSString *)fillMode {
    AVPlayerLayer *playerLayer = (AVPlayerLayer*)[self layer];
    playerLayer.videoGravity = fillMode;
}

- (void)setCurrentOrientation:(UIDeviceOrientation)currentOrientation {
    if (!self.playerLayer.isReadyForDisplay && currentOrientation != UIDeviceOrientationPortrait) {
        return;
    }
    if (_currentOrientation == currentOrientation || (currentOrientation != UIDeviceOrientationPortrait && !UIDeviceOrientationIsLandscape(currentOrientation))) {
        return;
    }
    _currentOrientation = currentOrientation;
    [self transfromWithOrientation:currentOrientation];
}

- (BOOL)prefersStatusBarHidden {
    return _prefersStatusBarHidden;
}

- (BOOL)isLandscape {
    return self.currentOrientation != UIDeviceOrientationPortrait && self.currentOrientation != UIDeviceOrientationUnknown;
}

- (BOOL)isPlaying {
    return self.player.rate != 0.f;
}

- (CMTime)playerItemDuration {
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        /*
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3.
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching
         the value of the duration property of its associated AVAsset object. However,
         note that for HTTP Live Streaming Media the duration of a player item during
         any particular playback session may differ from the duration of its asset. For
         this reason a new key-value observable duration property has been defined on
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         */
        
        return self.playerItem.duration;
    }
    
    return kCMTimeInvalid;
}

- (void)setToolBarsInactiveTimerWithTimeInterval:(NSTimeInterval)timeInterval {
    self.toolBarsInactiveTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                                  target:self
                                                                selector:@selector(timerFired:)
                                                                userInfo:nil
                                                                 repeats:NO];
}

@end
