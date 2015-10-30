//
//  ClusterPrePermissions.m
//  ClusterPrePermissions
//
//  Created by Rizwan Sattar on 4/7/14.
//  Copyright (c) 2014 Cluster Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
@import UIKit;
@import AddressBook;
@import Photos;
@import EventKit;
@import CoreLocation;
@import AVFoundation;

#import "ClusterPrePermissions.h"
#import "UIApplication+TopmostViewController.h"

typedef NS_ENUM(NSInteger, ClusterTitleType) {
  ClusterTitleTypeRequest = 0,
  ClusterTitleTypeDeny
};

NSString *const ClusterPrePermissionsDidAskForPushNotifications = @"ClusterPrePermissionsDidAskForPushNotifications";

@interface ClusterPrePermissions () <CLLocationManagerDelegate>

@property (copy, nonatomic) ClusterPrePermissionCompletionHandler avPermissionCompletionHandler;

@property (copy, nonatomic) ClusterPrePermissionCompletionHandler photoPermissionCompletionHandler;

@property (copy, nonatomic) ClusterPrePermissionCompletionHandler contactPermissionCompletionHandler;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler eventPermissionCompletionHandler;

@property (copy, nonatomic) ClusterPrePermissionCompletionHandler locationPermissionCompletionHandler;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (assign, nonatomic) ClusterLocationAuthorizationType locationAuthorizationType;
@property (assign, nonatomic) ClusterPushNotificationType requestedPushNotificationTypes;

@property (copy, nonatomic) ClusterPrePermissionCompletionHandler pushNotificationPermissionCompletionHandler;

- (NSString *)titleFor:(ClusterTitleType)titleType fromTitle:(NSString *)title;
- (NSUInteger)EKEquivalentEventType:(ClusterEventAuthorizationType)eventType;

@end

static ClusterPrePermissions *__sharedInstance;

@implementation ClusterPrePermissions

+ (instancetype) sharedPermissions
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[ClusterPrePermissions alloc] init];
    });
    return __sharedInstance;
}

+ (ClusterAuthorizationStatus) AVPermissionAuthorizationStatusForMediaType:(NSString*)mediaType
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case AVAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case AVAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) cameraPermissionAuthorizationStatus
{
    return [ClusterPrePermissions AVPermissionAuthorizationStatusForMediaType:AVMediaTypeVideo];
}

+ (ClusterAuthorizationStatus) microphonePermissionAuthorizationStatus
{
    return [ClusterPrePermissions AVPermissionAuthorizationStatusForMediaType:AVMediaTypeAudio];
}

+ (ClusterAuthorizationStatus) photoPermissionAuthorizationStatus
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case PHAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case PHAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) contactsPermissionAuthorizationStatus
{
  ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    switch (status) {
        case kABAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case kABAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case kABAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) eventPermissionAuthorizationStatus:(ClusterEventAuthorizationType)eventType
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:
                  [[ClusterPrePermissions sharedPermissions] EKEquivalentEventType:eventType]];
    switch (status) {
        case EKAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case EKAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case EKAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) locationPermissionAuthorizationStatus
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return ClusterAuthorizationStatusAuthorized;

        case kCLAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case kCLAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) pushNotificationPermissionAuthorizationStatus
{
    BOOL didAskForPermission = [[NSUserDefaults standardUserDefaults] boolForKey:ClusterPrePermissionsDidAskForPushNotifications];

    if (didAskForPermission) {
      if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
        return ClusterAuthorizationStatusAuthorized;
      } else {
        return ClusterAuthorizationStatusDenied;
      }
    } else {
        return ClusterAuthorizationStatusUnDetermined;
    }
}

- (UIViewController *)prePermissionControllerWithTitle:(NSString *)requestTitle
                                               message:(NSString *)message
                                       denyButtonTitle:(NSString *)denyButtonTitle
                                      grantButtonTitle:(NSString *)grantButtonTitle
                                            authorized:(dispatch_block_t)authorizedHandler
                                                denied:(dispatch_block_t)deniedHandler
{
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];
  
  [alertController addAction:[UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    deniedHandler();
  }]];
  [alertController addAction:[UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    authorizedHandler();
  }]];
  return alertController;
}


#pragma mark - Push Notification Permissions Help

- (UIViewController *) pushNotificationPermissionsWithType:(ClusterPushNotificationType)requestedType
                                           title:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Enable Push Notifications?";
    }
    denyButtonTitle = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    ClusterAuthorizationStatus status = [ClusterPrePermissions pushNotificationPermissionAuthorizationStatus];
    if (status == ClusterAuthorizationStatusUnDetermined) {
        self.pushNotificationPermissionCompletionHandler = completionHandler;
        self.requestedPushNotificationTypes = requestedType;
        return [self prePermissionControllerWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle authorized:^{
          [self showActualPushNotificationPermissionAlert];
        } denied:^{
           [self firePushNotificationPermissionCompletionHandler];
        }];
    } else {
        if (completionHandler) {
            completionHandler((status == ClusterAuthorizationStatusUnDetermined),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
  return nil;
}

- (void) showActualPushNotificationPermissionAlert
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)self.requestedPushNotificationTypes
                                                                             categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
  
    [[NSUserDefaults standardUserDefaults] setBool:YES
                                            forKey:ClusterPrePermissionsDidAskForPushNotifications];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidBecomeActive
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [self firePushNotificationPermissionCompletionHandler];
}


- (void) firePushNotificationPermissionCompletionHandler
{
    ClusterAuthorizationStatus status = [ClusterPrePermissions pushNotificationPermissionAuthorizationStatus];
    if (self.pushNotificationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ClusterAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ClusterAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ClusterAuthorizationStatusUnDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        }
        self.pushNotificationPermissionCompletionHandler((status == ClusterAuthorizationStatusAuthorized),
                                                         userDialogResult,
                                                         systemDialogResult);
        self.pushNotificationPermissionCompletionHandler = nil;
    }
}


#pragma mark - AV Permissions Help

- (UIViewController *) AVPermissionsWithType:(ClusterAVAuthorizationType)mediaType
                             title:(NSString *)requestTitle
                           message:(NSString *)message
                   denyButtonTitle:(NSString *)denyButtonTitle
                  grantButtonTitle:(NSString *)grantButtonTitle
                 completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        switch (mediaType) {
            case ClusterAVAuthorizationTypeCamera:
                requestTitle = @"Access Camera?";
                break;

            default:
                requestTitle = @"Access Microphone?";
                break;
        }
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:[self AVEquivalentMediaType:mediaType]];
    if (status == AVAuthorizationStatusNotDetermined) {
        self.avPermissionCompletionHandler = completionHandler;
        return [self prePermissionControllerWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle authorized:^{
          [self showActualAVPermissionAlertWithType:mediaType];
        } denied:^{
          [self fireAVPermissionCompletionHandlerWithType:mediaType];
        }];
    } else {
        if (completionHandler) {
            completionHandler((status == AVAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
  return nil;
}


- (UIViewController *) cameraPermissionsWithTitle:(NSString *)requestTitle
                                message:(NSString *)message
                        denyButtonTitle:(NSString *)denyButtonTitle
                       grantButtonTitle:(NSString *)grantButtonTitle
                      completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
   return [self AVPermissionsWithType:ClusterAVAuthorizationTypeCamera
                              title:requestTitle
                            message:message
                    denyButtonTitle:denyButtonTitle
                   grantButtonTitle:grantButtonTitle
                  completionHandler:completionHandler];
}


- (UIViewController *) microphonePermissionsWithTitle:(NSString *)requestTitle
                                    message:(NSString *)message
                            denyButtonTitle:(NSString *)denyButtonTitle
                           grantButtonTitle:(NSString *)grantButtonTitle
                          completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    return [self AVPermissionsWithType:ClusterAVAuthorizationTypeMicrophone
                              title:requestTitle
                            message:message
                    denyButtonTitle:denyButtonTitle
                   grantButtonTitle:grantButtonTitle
                  completionHandler:completionHandler];
}


- (void) showActualAVPermissionAlertWithType:(ClusterAVAuthorizationType)mediaType
{
    [AVCaptureDevice requestAccessForMediaType:[self AVEquivalentMediaType:mediaType]
                             completionHandler:^(BOOL granted) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     [self fireAVPermissionCompletionHandlerWithType:mediaType];
                                 });
                             }];
}


- (void) fireAVPermissionCompletionHandlerWithType:(ClusterAVAuthorizationType)mediaType
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:[self AVEquivalentMediaType:mediaType]];
    if (self.avPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == AVAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == AVAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == AVAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == AVAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.avPermissionCompletionHandler((status == AVAuthorizationStatusAuthorized),
                                           userDialogResult,
                                           systemDialogResult);
        self.avPermissionCompletionHandler = nil;
    }
}


- (NSString*)AVEquivalentMediaType:(ClusterAVAuthorizationType)mediaType
{
    if (mediaType == ClusterAVAuthorizationTypeCamera) {
        return AVMediaTypeVideo;
    }
    else {
        return AVMediaTypeAudio;
    }
}

#pragma mark - Photo Permissions Help

- (UIViewController *) photoPermissionsWithTitle:(NSString *)requestTitle
                               message:(NSString *)message
                       denyButtonTitle:(NSString *)denyButtonTitle
                      grantButtonTitle:(NSString *)grantButtonTitle
                     completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Photos?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        self.photoPermissionCompletionHandler = completionHandler;
      
      return [self prePermissionControllerWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle authorized:^{
        [self showActualPhotoPermissionAlert];
      } denied:^{
        [self firePhotoPermissionCompletionHandler];
      }];
    } else {
        if (completionHandler) {
            completionHandler((status == PHAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
  return nil;
}


- (void) showActualPhotoPermissionAlert
{
  [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    [self firePhotoPermissionCompletionHandler];
  }];
}


- (void) firePhotoPermissionCompletionHandler
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (self.photoPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == PHAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == PHAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == PHAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == PHAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.photoPermissionCompletionHandler((status == PHAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.photoPermissionCompletionHandler = nil;
    }
}


#pragma mark - Contact Permissions Help


- (UIViewController *) contactsPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Contacts?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
  
  ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (status == kABAuthorizationStatusNotDetermined) {
        self.contactPermissionCompletionHandler = completionHandler;
      return [self prePermissionControllerWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle authorized:^{
        [self showActualContactPermissionAlert];
      } denied:^{
        [self fireContactPermissionCompletionHandler];
      }];
    } else {
        if (completionHandler) {
            completionHandler((status == kABAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
  return nil;
}


- (void) showActualContactPermissionAlert
{
  ABAddressBookRequestAccessWithCompletion(ABAddressBookCreate(), ^(bool granted, CFErrorRef error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self fireContactPermissionCompletionHandler];
    });
  });
}


- (void) fireContactPermissionCompletionHandler
{
  ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
  if (self.contactPermissionCompletionHandler) {
      ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
      ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
      if (status == kABAuthorizationStatusNotDetermined) {
          userDialogResult = ClusterDialogResultDenied;
          systemDialogResult = ClusterDialogResultNoActionTaken;
      } else if (status == kABAuthorizationStatusAuthorized) {
          userDialogResult = ClusterDialogResultGranted;
          systemDialogResult = ClusterDialogResultGranted;
      } else if (status == kABAuthorizationStatusDenied) {
          userDialogResult = ClusterDialogResultGranted;
          systemDialogResult = ClusterDialogResultDenied;
      } else if (status == kABAuthorizationStatusRestricted) {
          userDialogResult = ClusterDialogResultGranted;
          systemDialogResult = ClusterDialogResultParentallyRestricted;
      }
      self.contactPermissionCompletionHandler((status == kABAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
      self.contactPermissionCompletionHandler = nil;
  }
}

#pragma mark - Event Permissions Help


- (UIViewController *) eventPermissionsWithType:(ClusterEventAuthorizationType)eventType
                                Title:(NSString *)requestTitle
                              message:(NSString *)message
                      denyButtonTitle:(NSString *)denyButtonTitle
                     grantButtonTitle:(NSString *)grantButtonTitle
                    completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        switch (eventType) {
            case ClusterEventAuthorizationTypeEvent:
                requestTitle = @"Access Calendar?";
                break;

            default:
                requestTitle = @"Access Reminders?";
                break;
        }
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:[self EKEquivalentEventType:eventType]];
    if (status == EKAuthorizationStatusNotDetermined) {
        self.eventPermissionCompletionHandler = completionHandler;
      return [self prePermissionControllerWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle authorized:^{
        [self showActualEventPermissionAlert:eventType];
      } denied:^{
        [self fireEventPermissionCompletionHandler:eventType];
      }];
    } else {
        if (completionHandler) {
            completionHandler((status == EKAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
  return nil;
}


- (void) showActualEventPermissionAlert:(ClusterEventAuthorizationType)eventType
{
    EKEventStore *aStore = [[EKEventStore alloc] init];
    [aStore requestAccessToEntityType:[self EKEquivalentEventType:eventType] completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireEventPermissionCompletionHandler:eventType];
        });
    }];
}


- (void) fireEventPermissionCompletionHandler:(ClusterEventAuthorizationType)eventType
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:[self EKEquivalentEventType:eventType]];
    if (self.eventPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == EKAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == EKAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == EKAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == EKAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.eventPermissionCompletionHandler((status == EKAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.eventPermissionCompletionHandler = nil;
    }
}

- (NSUInteger)EKEquivalentEventType:(ClusterEventAuthorizationType)eventType {
    if (eventType == ClusterEventAuthorizationTypeEvent) {
        return EKEntityTypeEvent;
    }
    else {
        return EKEntityTypeReminder;
    }
}

#pragma mark - Location Permission Help



- (UIViewController *) locationPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    return [self locationPermissionsForAuthorizationType:ClusterLocationAuthorizationTypeAlways
                                                title:requestTitle
                                              message:message
                                      denyButtonTitle:denyButtonTitle
                                     grantButtonTitle:grantButtonTitle
                                    completionHandler:completionHandler];
}

- (UIViewController *) locationPermissionsForAuthorizationType:(ClusterLocationAuthorizationType)authorizationType
                                               title:(NSString *)requestTitle
                                             message:(NSString *)message
                                     denyButtonTitle:(NSString *)denyButtonTitle
                                    grantButtonTitle:(NSString *)grantButtonTitle
                                   completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Location?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.locationPermissionCompletionHandler = completionHandler;
        self.locationAuthorizationType = authorizationType;
      return [self prePermissionControllerWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle authorized:^{
        [self showActualLocationPermissionAlert];
      } denied:^{
        [self fireLocationPermissionCompletionHandler];
      }];
    } else {
        if (completionHandler) {
            completionHandler(([self locationAuthorizationStatusPermitsAccess:status]),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
  return nil;
}


- (void) showActualLocationPermissionAlert
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    if (self.locationAuthorizationType == ClusterLocationAuthorizationTypeAlways &&
        [self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {

        [self.locationManager requestAlwaysAuthorization];

    } else if (self.locationAuthorizationType == ClusterLocationAuthorizationTypeWhenInUse &&
               [self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {

        [self.locationManager requestWhenInUseAuthorization];
    }

    [self.locationManager startUpdatingLocation];
}


- (void) fireLocationPermissionCompletionHandler
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (self.locationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kCLAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if ([self locationAuthorizationStatusPermitsAccess:status]) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == kCLAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == kCLAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.locationPermissionCompletionHandler(([self locationAuthorizationStatusPermitsAccess:status]),
                                                 userDialogResult,
                                                 systemDialogResult);
        self.locationPermissionCompletionHandler = nil;
    }
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation], self.locationManager = nil;
    }
}

- (BOOL)locationAuthorizationStatusPermitsAccess:(CLAuthorizationStatus)authorizationStatus
{
    return authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ||
    authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse;
}

#pragma mark CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self fireLocationPermissionCompletionHandler];
    }
}


#pragma mark - Helpers

- (void)showAVPermissionsWithType:(ClusterAVAuthorizationType)mediaType title:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self AVPermissionsWithType:mediaType title:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showCameraPermissionsWithTitle:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self cameraPermissionsWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showContactsPermissionsWithTitle:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self contactsPermissionsWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showEventPermissionsWithType:(ClusterEventAuthorizationType)eventType Title:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self eventPermissionsWithType:eventType Title:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showLocationPermissionsForAuthorizationType:(ClusterLocationAuthorizationType)authorizationType title:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self locationPermissionsForAuthorizationType:authorizationType title:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showLocationPermissionsWithTitle:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self locationPermissionsWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showMicrophonePermissionsWithTitle:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self microphonePermissionsWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showPhotoPermissionsWithTitle:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self photoPermissionsWithTitle:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)showPushNotificationPermissionsWithType:(ClusterPushNotificationType)requestedType title:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
  [self present:[self pushNotificationPermissionsWithType:requestedType title:requestTitle message:message denyButtonTitle:denyButtonTitle grantButtonTitle:grantButtonTitle completionHandler:completionHandler]];
}

- (void)present:(UIViewController *)viewController
{
  if (viewController == nil) {
    return;
  }
  [[[UIApplication sharedApplication] topMostViewController] presentViewController:viewController animated:YES completion:nil];
}


#pragma mark - Titles

- (NSString *)titleFor:(ClusterTitleType)titleType fromTitle:(NSString *)title
{
    switch (titleType) {
        case ClusterTitleTypeDeny:
            title = (title.length == 0) ? @"Not Now" : title;
            break;
        case ClusterTitleTypeRequest:
            title = (title.length == 0) ? @"Give Access" : title;
            break;
        default:
            title = @"";
            break;
    }
    return title;
}

@end
