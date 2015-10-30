//
//  UIApplication+TopmostViewController.m
//  ClusterPrePermissions
//
//  Created by Florent Vilmart on 15-10-30.
//  Copyright © 2015 Cluster Labs, Inc. All rights reserved.
//

#import "UIApplication+TopmostViewController.h"

@implementation UIViewController (TopMostViewController)

- (UIViewController *)topMostViewController
{
  if (self.presentedViewController == nil)
  {
    return self;
  }
  else if ([self.presentedViewController isKindOfClass:[UINavigationController class]])
  {
    UINavigationController *navigationController = (UINavigationController *)self.presentedViewController;
    UIViewController *lastViewController = [[navigationController viewControllers] lastObject];
    return [lastViewController topMostViewController];
  }
  
  UIViewController *presentedViewController = (UIViewController *)self.presentedViewController;
  return [presentedViewController topMostViewController];
}

@end

@implementation UIApplication (TopmostViewController)

- (UIViewController *)topMostViewController
{
  return [self.keyWindow.rootViewController topMostViewController];
}

@end

