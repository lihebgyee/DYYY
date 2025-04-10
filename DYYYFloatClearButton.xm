/* 
 * Tweak Name: 1KeyHideDYUI
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <signal.h>
// HideUIButton 接口声明
@interface HideUIButton : UIButton
// 状态属性
@property (nonatomic, assign) BOOL isElementsHidden;
@property (nonatomic, assign) BOOL isLocked;
// UI 相关属性
@property (nonatomic, strong) NSMutableArray *hiddenViewsList;
@property (nonatomic, strong) UIImage *showIcon;
@property (nonatomic, strong) UIImage *hideIcon;
@property (nonatomic, assign) CGFloat originalAlpha;
// 计时器属性
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, strong) NSTimer *fadeTimer;
// 方法声明
- (void)resetFadeTimer;
- (void)hideUIElements;
- (void)findAndHideViews:(NSArray *)classNames;
- (void)safeResetState;
- (void)startPeriodicCheck;
- (UIViewController *)findViewController:(UIView *)view;
- (void)loadIcons;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
- (void)handleTap;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)handleTouchDown;
- (void)handleTouchUpInside;
- (void)handleTouchUpOutside;
- (void)saveLockState;
- (void)loadLockState;
@end
// 全局变量
static HideUIButton *hideButton;
static BOOL isAppInTransition = NO;
static NSArray *targetClassNames;
// 使用与倍速相同的 Toast 样式
static inline void showToast(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        UILabel *toastLabel = [[UILabel alloc] init];
        toastLabel.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.95];
        toastLabel.textColor = [UIColor whiteColor];
        toastLabel.textAlignment = NSTextAlignmentCenter;
        toastLabel.font = [UIFont systemFontOfSize:16];
        toastLabel.text = text;
        toastLabel.alpha = 0;
        toastLabel.layer.cornerRadius = 22; 
        toastLabel.clipsToBounds = YES;
        
        [toastLabel sizeToFit];
        CGFloat horizontalPadding = 24;
        CGFloat verticalPadding = 12;
        CGFloat width = toastLabel.frame.size.width + horizontalPadding * 2;
        CGFloat height = toastLabel.frame.size.height + verticalPadding * 2;
        
        width = MAX(width, 120);
        
        toastLabel.frame = CGRectMake(0, 0, width, height);
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        toastLabel.center = CGPointMake(screenBounds.size.width / 2, screenBounds.size.height / 2);
        
        [window addSubview:toastLabel];
        
        [UIView animateWithDuration:0.2 animations:^{
            toastLabel.alpha = 1;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.2 animations:^{
                    toastLabel.alpha = 0;
                } completion:^(BOOL finished) {
                    [toastLabel removeFromSuperview];
                }];
            });
        }];
    });
}
static void findViewsOfClassHelper(UIView *view, Class viewClass, NSMutableArray *result) {
    if ([view isKindOfClass:viewClass]) {
        [result addObject:view];
    }
    
    for (UIView *subview in view.subviews) {
        findViewsOfClassHelper(subview, viewClass, result);
    }
}
static UIWindow* getKeyWindow(void) {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    return keyWindow;
}
static void forceResetAllUIElements(void) {
    UIWindow *window = getKeyWindow();
    if (!window) return;
    
    for (NSString *className in targetClassNames) {
        Class viewClass = NSClassFromString(className);
        if (!viewClass) continue;
        
        NSMutableArray *views = [NSMutableArray array];
        findViewsOfClassHelper(window, viewClass, views);
        
        for (UIView *view in views) {
            view.alpha = 1.0;
        }
    }
}
static void reapplyHidingToAllElements(HideUIButton *button) {
    if (!button || !button.isElementsHidden) return;
    [button hideUIElements];
}
static void initTargetClassNames(void) {
    targetClassNames = @[
        @"AWEHPTopBarCTAContainer",
        @"AWEHPDiscoverFeedEntranceView",
        @"AWELeftSideBarEntranceView",
        @"DUXBadge",
        @"AWEBaseElementView",
        @"AWEElementStackView",
        @"AWEPlayInteractionDescriptionLabel",
        @"AWEUserNameLabel",
        @"AWEStoryProgressSlideView",
        @"AWEStoryProgressContainerView",
        @"ACCEditTagStickerView",
        @"AWEFeedTemplateAnchorView",
        @"AWESearchFeedTagView",
        @"AWEPlayInteractionSearchAnchorView",
        @"AFDRecommendToFriendTagView",
        @"AWELandscapeFeedEntryView",
        @"AWEFeedAnchorContainerView",
        @"AFDAIbumFolioView"
    ];
}

@implementation HideUIButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.masksToBounds = YES;
        
        self.isElementsHidden = NO;
        self.hiddenViewsList = [NSMutableArray array];
        self.originalAlpha = 1.0;
        
        // 加载保存的锁定状态
        [self loadLockState];
        
        [self loadIcons];
        [self setImage:self.showIcon forState:UIControlStateNormal];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGesture];
        
        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        [self addTarget:self action:@selector(handleTouchUpOutside) forControlEvents:UIControlEventTouchUpOutside];
        
        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPressGesture];
        
        [self startPeriodicCheck];
        [self resetFadeTimer];
    }
    return self;
}
- (void)startPeriodicCheck {
    [self.checkTimer invalidate];
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 
                                                     repeats:YES 
                                                       block:^(NSTimer *timer) {
        if (self.isElementsHidden) {
            [self hideUIElements];
        }
    }];
}
- (void)resetFadeTimer {
    [self.fadeTimer invalidate];
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 
                                                    repeats:NO 
                                                      block:^(NSTimer *timer) {
        [UIView animateWithDuration:0.3 animations:^{
            self.alpha = 0.5;
        }];
    }];
    
    if (self.alpha != self.originalAlpha) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = self.originalAlpha;
        }];
    }
}
- (void)saveLockState {
    [[NSUserDefaults standardUserDefaults] setBool:self.isLocked forKey:@"HideUIButtonLockState"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)loadLockState {
    self.isLocked = [[NSUserDefaults standardUserDefaults] boolForKey:@"HideUIButtonLockState"];
}
- (void)loadIcons {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *iconPath = [documentsPath stringByAppendingPathComponent:@"DYYY/Qingping.png"];
    
    UIImage *customIcon = [UIImage imageWithContentsOfFile:iconPath];
    if (customIcon) {
        self.showIcon = customIcon;
        self.hideIcon = customIcon;
    } else {
        [self setTitle:@"隐藏" forState:UIControlStateNormal];
        [self setTitle:@"显示" forState:UIControlStateSelected];
        self.titleLabel.font = [UIFont systemFontOfSize:10];
    }
}
- (void)handleTouchDown {
    [self resetFadeTimer];
}
- (void)handleTouchUpInside {
    [self resetFadeTimer];
}
- (void)handleTouchUpOutside {
    [self resetFadeTimer];
}
- (UIViewController *)findViewController:(UIView *)view {
    __weak UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
        if (!responder) break;
    }
    return nil;
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.isLocked) return;
    
    [self resetFadeTimer];
    
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    
    newCenter.x = MAX(self.frame.size.width / 2, MIN(newCenter.x, self.superview.frame.size.width - self.frame.size.width / 2));
    newCenter.y = MAX(self.frame.size.height / 2, MIN(newCenter.y, self.superview.frame.size.height - self.frame.size.height / 2));
    
    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGPoint(self.center) forKey:@"HideUIButtonPosition"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
- (void)handleTap {
    if (isAppInTransition) return;
    
    [self resetFadeTimer];
    
    if (!self.isElementsHidden) {
        [self hideUIElements];
        self.isElementsHidden = YES;
        self.selected = YES;
    } else {
        forceResetAllUIElements();
        self.isElementsHidden = NO;
        [self.hiddenViewsList removeAllObjects];
        self.selected = NO;
    }
}
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self resetFadeTimer];
        self.isLocked = !self.isLocked;
        
        // 保存锁定状态
        [self saveLockState];
        
        NSString *toastMessage = self.isLocked ? @"按钮已锁定" : @"按钮已解锁";
        showToast(toastMessage);
        
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
    }
}
- (void)hideUIElements {
    [self.hiddenViewsList removeAllObjects];
    [self findAndHideViews:targetClassNames];
    self.isElementsHidden = YES;
}
- (void)findAndHideViews:(NSArray *)classNames {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        for (NSString *className in classNames) {
            Class viewClass = NSClassFromString(className);
            if (!viewClass) continue;
            
            NSMutableArray *views = [NSMutableArray array];
            findViewsOfClassHelper(window, viewClass, views);
            
            for (UIView *view in views) {
                if ([view isKindOfClass:[UIView class]]) {
                    if ([view isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                        UIViewController *controller = [self findViewController:view];
                        if (![controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                            continue;
                        }
                    }
                    
                    [self.hiddenViewsList addObject:view];
                    view.alpha = 0.0;
                }
            }
        }
    }
}
- (void)safeResetState {
    forceResetAllUIElements();
    self.isElementsHidden = NO;
    [self.hiddenViewsList removeAllObjects];
    self.selected = NO;
}
- (void)dealloc {
    [self.checkTimer invalidate];
    [self.fadeTimer invalidate];
    self.checkTimer = nil;
    self.fadeTimer = nil;
}
@end
// Hook 部分
%hook UIView
- (id)initWithFrame:(CGRect)frame {
    UIView *view = %orig;
    if (hideButton && hideButton.isElementsHidden) {
        for (NSString *className in targetClassNames) {
            if ([view isKindOfClass:NSClassFromString(className)]) {
                if ([view isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIViewController *controller = [hideButton findViewController:view];
                        if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                            view.alpha = 0.0;
                        }
                    });
                    break;
                }
                view.alpha = 0.0;
                break;
            }
        }
    }
    return view;
}
- (void)didAddSubview:(UIView *)subview {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        for (NSString *className in targetClassNames) {
            if ([subview isKindOfClass:NSClassFromString(className)]) {
                if ([subview isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                    UIViewController *controller = [hideButton findViewController:subview];
                    if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                        subview.alpha = 0.0;
                    }
                    break;
                }
                subview.alpha = 0.0;
                break;
            }
        }
    }
}
- (void)willMoveToSuperview:(UIView *)newSuperview {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        for (NSString *className in targetClassNames) {
            if ([self isKindOfClass:NSClassFromString(className)]) {
                if ([self isKindOfClass:NSClassFromString(@"AWELeftSideBarEntranceView")]) {
                    UIViewController *controller = [hideButton findViewController:self];
                    if ([controller isKindOfClass:NSClassFromString(@"AWEFeedContainerViewController")]) {
                        self.alpha = 0.0;
                    }
                    break;
                }
                self.alpha = 0.0;
                break;
            }
        }
    }
}
%end
%hook AWEFeedTableViewCell
- (void)prepareForReuse {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}
- (void)layoutSubviews {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
}
%end
%hook AWEFeedViewCell
- (void)layoutSubviews {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}
- (void)setModel:(id)model {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}
%end
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    isAppInTransition = YES;
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isAppInTransition = NO;
    });
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    isAppInTransition = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isAppInTransition = NO;
    });
}
%end
%hook AWEFeedContainerViewController
- (void)aweme:(id)arg1 currentIndexWillChange:(NSInteger)arg2 {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}
- (void)aweme:(id)arg1 currentIndexDidChange:(NSInteger)arg2 {
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
    %orig;
}
- (void)viewWillLayoutSubviews {
    %orig;
    if (hideButton && hideButton.isElementsHidden) {
        [hideButton hideUIElements];
    }
}
%end
%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    initTargetClassNames();
    
    BOOL isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFloatClearButton"];
    
    if (isEnabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (hideButton) {
                [hideButton removeFromSuperview];
                hideButton = nil;
            }
            
            hideButton = [[HideUIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
            
            NSString *savedPositionString = [[NSUserDefaults standardUserDefaults] objectForKey:@"HideUIButtonPosition"];
            if (savedPositionString) {
                hideButton.center = CGPointFromString(savedPositionString);
            } else {
                CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
                CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
                hideButton.center = CGPointMake(screenWidth - 35, screenHeight / 2);
            }
            
            [getKeyWindow() addSubview:hideButton];
        });
    }
    
    return result;
}
%end
%ctor {
    signal(SIGSEGV, SIG_IGN);
}