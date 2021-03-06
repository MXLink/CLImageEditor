//
//  CLEffectTool.m
//
//  Created by sho yakushiji on 2013/10/23.
//  Copyright (c) 2013年 CALACULU. All rights reserved.
//

#import "CLEffectTool.h"


@interface CLEffectTool()
@property (nonatomic, strong) UIView *selectedMenu;
@property (nonatomic, strong) CLEffectBase *selectedEffect;
@end


@implementation CLEffectTool
{
    UIImage *_originalImage;
    UIImage *_thumnailImage;
    
    UIScrollView *_menuScroll;
    UIActivityIndicatorView *_indicatorView;
}

+ (NSArray*)subtools
{
    return [CLImageToolInfo toolsWithToolClass:[CLEffectBase class]];
}

+ (NSString*)defaultTitle
{
    return NSLocalizedStringWithDefaultValue(@"CLEffectTool_DefaultTitle", nil, [CLImageEditorTheme bundle], @"Effect", @"");
}

+ (BOOL)isAvailable
{
    return ([UIDevice iosVersion] >= 5.0);
}

#pragma mark- 

- (void)setup
{
    _originalImage = self.editor.imageView.image;
    _thumnailImage = [_originalImage resize:self.editor.imageView.frame.size];
    
    [self.editor fixZoomScaleWithAnimated:YES];
    
    _menuScroll = [[UIScrollView alloc] initWithFrame:self.editor.menuView.frame];
    _menuScroll.backgroundColor = self.editor.menuView.backgroundColor;
    _menuScroll.showsHorizontalScrollIndicator = NO;
    [self.editor.view addSubview:_menuScroll];
    
    [self setEffectMenu];
    
    _menuScroll.transform = CGAffineTransformMakeTranslation(0, self.editor.view.height-_menuScroll.top);
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         _menuScroll.transform = CGAffineTransformIdentity;
                     }];
}

- (void)cleanup
{
    [self.selectedEffect cleanup];
    [_indicatorView removeFromSuperview];
    
    [self.editor resetZoomScaleWithAnimated:YES];
    
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         _menuScroll.transform = CGAffineTransformMakeTranslation(0, self.editor.view.height-_menuScroll.top);
                     }
                     completion:^(BOOL finished) {
                         [_menuScroll removeFromSuperview];
                     }];
}

- (void)executeWithCompletionBlock:(void(^)(UIImage *image, NSError *error, NSDictionary *userInfo))completionBlock
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _indicatorView = [CLImageEditorTheme indicatorView];
        _indicatorView.center = self.editor.view.center;
        [self.editor.view addSubview:_indicatorView];
        [_indicatorView startAnimating];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self.selectedEffect applyEffect:_originalImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(image, nil, nil);
        });
    });
}

#pragma mark- 

- (void)setEffectMenu
{
    CGFloat W = 70;
    CGFloat x = 0;
    
    for(CLImageToolInfo *info in self.toolInfo.sortedSubtools){
        if(!info.available){
            continue;
        }
        
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(x, 0, W, _menuScroll.height)];
        view.toolInfo = info;
        
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 5, 50, 50)];
        iconView.clipsToBounds = YES;
        iconView.layer.cornerRadius = 5;
        iconView.contentMode = UIViewContentModeScaleAspectFill;
        iconView.image = info.iconImage;
        [view addSubview:iconView];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, W-10, W, 15)];
        label.backgroundColor = [UIColor clearColor];
        label.text = info.title;
        label.textColor = [CLImageEditorTheme toolbarTextColor];
        label.font = [CLImageEditorTheme toolbarTextFont];
        label.textAlignment = NSTextAlignmentCenter;
        [view addSubview:label];
        
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMenu:)];
        [view addGestureRecognizer:gesture];
        
        [_menuScroll addSubview:view];
        x += W;
        
        if(self.selectedMenu==nil){
            self.selectedMenu = view;
        }
    }
    _menuScroll.contentSize = CGSizeMake(MAX(x, _menuScroll.frame.size.width+1), 0);
}

- (void)tappedMenu:(UITapGestureRecognizer*)sender
{
    UIView *view = sender.view;
    
    view.alpha = 0.2;
    [UIView animateWithDuration:kCLImageToolAnimationDuration
                     animations:^{
                         view.alpha = 1;
                     }
     ];
    
    self.selectedMenu = view;
}

- (void)setSelectedMenu:(UIView *)selectedMenu
{
    if(selectedMenu != _selectedMenu){
        _selectedMenu.backgroundColor = [UIColor clearColor];
        _selectedMenu = selectedMenu;
        _selectedMenu.backgroundColor = [CLImageEditorTheme toolbarSelectedButtonColor];
        
        Class effectClass = NSClassFromString(_selectedMenu.toolInfo.toolName);
        self.selectedEffect = [[effectClass alloc] initWithSuperView:self.editor.imageView.superview imageViewFrame:self.editor.imageView.frame toolInfo:_selectedMenu.toolInfo];
    }
}

- (void)setSelectedEffect:(CLEffectBase *)selectedEffect
{
    if(selectedEffect != _selectedEffect){
        [_selectedEffect cleanup];
        _selectedEffect = selectedEffect;
        _selectedEffect.delegate = self;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self buildThumnailImage];
        });
    }
}

- (void)buildThumnailImage
{
    UIImage *image;
    if(self.selectedEffect.needsThumnailPreview){
        image = [self.selectedEffect applyEffect:_thumnailImage];
    }
    else{
        image = [self.selectedEffect applyEffect:_originalImage];
    }
    [self.editor.imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
}

#pragma mark- CLEffect delegate

- (void)effectParameterDidChange:(CLEffectBase *)effect
{
    if(effect == self.selectedEffect){
        static BOOL inProgress = NO;
        
        if(inProgress){ return; }
        inProgress = YES;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self buildThumnailImage];
            inProgress = NO;
        });
    }
}

@end
