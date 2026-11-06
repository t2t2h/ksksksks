// Mubdi Speed — hacker-style animated menu (blue & black)
// Exclusive to "Mubdi"  |  Credit: Aflatoon (أفلاطون)
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "SpeedCore.h"

#define MB_BLUE [UIColor colorWithRed:0.10 green:0.50 blue:1.00 alpha:1]
#define MB_CYAN [UIColor colorWithRed:0.30 green:0.85 blue:1.00 alpha:1]
#define MB_DIM  [UIColor colorWithRed:0.45 green:0.60 blue:0.80 alpha:1]
#define MB_BG   [UIColor colorWithRed:0.015 green:0.03 blue:0.07 alpha:0.96]

static NSString *const kScale = @"mb_scale";
static NSString *const kOn    = @"mb_on";
static NSString *const kWall  = @"mb_wall";

static UILabel *MBL(NSString *t, CGFloat sz, UIColor *c, NSTextAlignment a, CGRect f) {
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.text = t; l.textColor = c; l.textAlignment = a;
    l.font = [UIFont fontWithName:@"Menlo-Bold" size:sz];
    return l;
}

#pragma mark - Pass-through window

@interface MBPassWindow : UIWindow @end
@implementation MBPassWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    if (v == self || v == self.rootViewController.view) return nil;
    return v;
}
@end

#pragma mark - Menu

@interface MBMenuVC : UIViewController
@property (nonatomic, strong) UIButton *fab;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *titleLbl, *scaleLbl, *statsLbl;
@property (nonatomic, strong) UISwitch *onSw, *wallSw;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, assign) NSUInteger idx;
@property (nonatomic, assign) BOOL blink, placed;
@end

@implementation MBMenuVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    [self buildFab];
    [self buildPanel];

    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    double sc = [d objectForKey:kScale] ? [d doubleForKey:kScale] : 2.0;
    _onSw.on = [d boolForKey:kOn];
    _wallSw.on = [d boolForKey:kWall];
    [self setScale:sc];

    [NSTimer scheduledTimerWithTimeInterval:0.08 target:self selector:@selector(typeTick) userInfo:nil repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(statsTick) userInfo:nil repeats:YES];
}

- (void)buildFab {
    _fab = [UIButton buttonWithType:UIButtonTypeCustom];
    _fab.frame = CGRectMake(16, 120, 50, 50);
    _fab.backgroundColor = MB_BG;
    _fab.layer.cornerRadius = 25;
    _fab.layer.borderWidth = 2;
    _fab.layer.borderColor = MB_BLUE.CGColor;
    _fab.layer.shadowColor = MB_BLUE.CGColor;
    _fab.layer.shadowOpacity = 0.9;
    _fab.layer.shadowOffset = CGSizeZero;
    _fab.layer.shadowRadius = 10;
    [_fab setTitle:@"M" forState:UIControlStateNormal];
    [_fab setTitleColor:MB_CYAN forState:UIControlStateNormal];
    _fab.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:22];

    CABasicAnimation *g = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    g.fromValue = @4; g.toValue = @18; g.duration = 1.1;
    g.autoreverses = YES; g.repeatCount = HUGE_VALF;
    [_fab.layer addAnimation:g forKey:@"glow"];

    [_fab addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [_fab addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    [self.view addSubview:_fab];
}

- (void)buildPanel {
    const CGFloat W = 290, H = 306, P = 14, IW = W - 2 * P;
    _panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    _panel.backgroundColor = MB_BG;
    _panel.layer.cornerRadius = 14;
    _panel.layer.borderWidth = 1.5;
    _panel.layer.borderColor = MB_BLUE.CGColor;
    _panel.layer.shadowColor = MB_BLUE.CGColor;
    _panel.layer.shadowOpacity = 0.8;
    _panel.layer.shadowRadius = 14;
    _panel.layer.shadowOffset = CGSizeZero;
    _panel.hidden = YES;

    CABasicAnimation *bc = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    bc.fromValue = (id)MB_BLUE.CGColor; bc.toValue = (id)MB_CYAN.CGColor;
    bc.duration = 1.4; bc.autoreverses = YES; bc.repeatCount = HUGE_VALF;
    [_panel.layer addAnimation:bc forKey:@"pulse"];

    // scan-line animation
    CALayer *host = [CALayer layer];
    host.frame = CGRectMake(0, 0, W, H);
    host.cornerRadius = 14; host.masksToBounds = YES;
    CAGradientLayer *scan = [CAGradientLayer layer];
    scan.frame = CGRectMake(0, 0, W, 3);
    scan.colors = @[(id)UIColor.clearColor.CGColor, (id)[MB_BLUE colorWithAlphaComponent:0.55].CGColor, (id)UIColor.clearColor.CGColor];
    scan.startPoint = CGPointMake(0, 0.5); scan.endPoint = CGPointMake(1, 0.5);
    CABasicAnimation *mv = [CABasicAnimation animationWithKeyPath:@"position.y"];
    mv.fromValue = @0; mv.toValue = @(H); mv.duration = 2.6; mv.repeatCount = HUGE_VALF;
    [scan addAnimation:mv forKey:@"scan"];
    [host addSublayer:scan];
    [_panel.layer addSublayer:host];

    // header (drag handle)
    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 50)];
    [head addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)]];
    _titleLbl = MBL(@"", 10, MB_CYAN, NSTextAlignmentLeft, CGRectMake(P, 10, IW, 18));
    [head addSubview:_titleLbl];
    [head addSubview:MBL(@"[ EXCLUSIVE  ·  MUBDI ]", 10, MB_DIM, NSTextAlignmentLeft, CGRectMake(P, 30, IW, 14))];
    [_panel addSubview:head];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(P, 52, IW, 1)];
    line.backgroundColor = [MB_BLUE colorWithAlphaComponent:0.5];
    [_panel addSubview:line];

    // enable
    [_panel addSubview:MBL(@"SPEED HACK", 12, MB_CYAN, NSTextAlignmentLeft, CGRectMake(P, 64, 160, 31))];
    _onSw = [[UISwitch alloc] initWithFrame:CGRectMake(W - P - 51, 64, 51, 31)];
    _onSw.onTintColor = MB_BLUE;
    [_onSw addTarget:self action:@selector(onChanged) forControlEvents:UIControlEventValueChanged];
    [_panel addSubview:_onSw];

    // scale + slider
    _scaleLbl = MBL(@"x1.00", 24, UIColor.whiteColor, NSTextAlignmentCenter, CGRectMake(P, 102, IW, 30));
    [_panel addSubview:_scaleLbl];
    _slider = [[UISlider alloc] initWithFrame:CGRectMake(P, 136, IW, 30)];
    _slider.minimumValue = 0.1; _slider.maximumValue = 10;
    _slider.minimumTrackTintColor = MB_BLUE;
    _slider.thumbTintColor = MB_CYAN;
    [_slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
    [_panel addSubview:_slider];

    // presets
    NSArray *pre = @[@0.5, @1, @2, @3, @5, @10];
    CGFloat bw = (IW - 5 * 6) / 6;
    for (NSUInteger i = 0; i < pre.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(P + i * (bw + 6), 174, bw, 28);
        b.tag = i;
        b.layer.cornerRadius = 6; b.layer.borderWidth = 1;
        b.layer.borderColor = MB_BLUE.CGColor;
        [b setTitle:[NSString stringWithFormat:@"x%g", [pre[i] doubleValue]] forState:UIControlStateNormal];
        [b setTitleColor:MB_CYAN forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:10];
        [b addTarget:self action:@selector(preset:) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:b];
    }

    // wall clock
    [_panel addSubview:MBL(@"WALL-CLOCK HOOK", 11, MB_DIM, NSTextAlignmentLeft, CGRectMake(P, 212, 170, 31))];
    _wallSw = [[UISwitch alloc] initWithFrame:CGRectMake(W - P - 51, 212, 51, 31)];
    _wallSw.onTintColor = MB_BLUE;
    [_wallSw addTarget:self action:@selector(wallChanged) forControlEvents:UIControlEventValueChanged];
    [_panel addSubview:_wallSw];

    // stats
    _statsLbl = MBL(@"", 10, MB_CYAN, NSTextAlignmentLeft, CGRectMake(P, 250, IW, 28));
    _statsLbl.numberOfLines = 2;
    [_panel addSubview:_statsLbl];

    // footer
    [_panel addSubview:MBL(@"by Aflatoon · أفلاطون", 10, MB_DIM, NSTextAlignmentCenter, CGRectMake(P, 282, IW, 16))];

    [self.view addSubview:_panel];
}

#pragma mark Actions

- (void)setScale:(double)v {
    v = round(v * 20) / 20.0;
    if (v < 0.1) v = 0.1; if (v > 10) v = 10;
    _slider.value = v;
    _scaleLbl.text = [NSString stringWithFormat:@"x%.2f", v];
    MBSpeedSetScale(v);
    [NSUserDefaults.standardUserDefaults setDouble:v forKey:kScale];
}
- (void)sliderChanged { [self setScale:_slider.value]; }
- (void)preset:(UIButton *)b {
    double vals[] = {0.5, 1, 2, 3, 5, 10};
    [self setScale:vals[b.tag]];
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];
}
- (void)onChanged {
    MBSpeedSetEnabled(_onSw.on);
    [NSUserDefaults.standardUserDefaults setBool:_onSw.on forKey:kOn];
}
- (void)wallChanged {
    MBSpeedSetWallClock(_wallSw.on);
    [NSUserDefaults.standardUserDefaults setBool:_wallSw.on forKey:kWall];
}

- (void)togglePanel {
    if (!_placed) {
        CGSize s = self.view.bounds.size;
        _panel.center = CGPointMake(s.width / 2, MAX(_panel.bounds.size.height / 2 + 10, s.height / 2));
        _placed = YES;
    }
    if (_panel.hidden) {
        _panel.hidden = NO; _panel.alpha = 0;
        _panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.6
                            options:0 animations:^{ self.panel.alpha = 1; self.panel.transform = CGAffineTransformIdentity; } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{ self.panel.alpha = 0; self.panel.transform = CGAffineTransformMakeScale(0.9, 0.9); }
                         completion:^(BOOL f) { self.panel.hidden = YES; }];
    }
}

- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    g.view.center = CGPointMake(g.view.center.x + t.x, g.view.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view];
}
- (void)dragPanel:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    _panel.center = CGPointMake(_panel.center.x + t.x, _panel.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view];
}

#pragma mark Timers

- (void)typeTick {
    NSString *full = @"./mubdi_speed --inject";
    if (_idx < full.length) _idx++; else _blink = !_blink;
    BOOL cur = (_idx < full.length) || _blink;
    _titleLbl.text = [NSString stringWithFormat:@"root@mubdi:~$ %@%@", [full substringToIndex:_idx], cur ? @"█" : @" "];
}
- (void)statsTick {
    if (_panel.hidden) return;
    double g, r;
    MBSpeedStats(&g, &r);
    _statsLbl.text = [NSString stringWithFormat:@"GAME TIME  %.1fs\nREAL TIME  %.1fs", g, r];
}

#pragma mark Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGPoint c = _fab.center;
    c.x = MIN(MAX(c.x, 25), b.size.width - 25);
    c.y = MIN(MAX(c.y, 25), b.size.height - 25);
    _fab.center = c;
    if (_placed) {
        CGPoint pc = _panel.center;
        CGSize ps = _panel.bounds.size;
        pc.x = MIN(MAX(pc.x, ps.width / 2), MAX(b.size.width - ps.width / 2, ps.width / 2));
        pc.y = MIN(MAX(pc.y, ps.height / 2), MAX(b.size.height - ps.height / 2, ps.height / 2));
        _panel.center = pc;
    }
}
@end

#pragma mark - Bootstrap

static MBPassWindow *gWin;

static void MBShowMenu(void) {
    if (gWin) return;
    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class] && s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s; break;
        }
    }
    if (!scene) return;
    gWin = [[MBPassWindow alloc] initWithWindowScene:scene];
    gWin.windowLevel = UIWindowLevelAlert + 100;
    gWin.backgroundColor = UIColor.clearColor;
    gWin.rootViewController = [MBMenuVC new];
    gWin.hidden = NO;
}

__attribute__((constructor)) static void mb_init(void) {
    MBSpeedInstall();
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    MBSpeedSetScale([d objectForKey:kScale] ? [d doubleForKey:kScale] : 2.0);
    MBSpeedSetEnabled([d boolForKey:kOn]);
    MBSpeedSetWallClock([d boolForKey:kWall]);

    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                    object:nil queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *n) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ MBShowMenu(); });
    }];
}
