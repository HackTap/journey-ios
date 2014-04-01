//
//  JCUserViewController.m
//  JourneyCapture
//
//  Created by Chris Sloey on 27/02/2014.
//  Copyright (c) 2014 FCD. All rights reserved.
//

#import "JCUserViewController.h"
#import "JCUserViewModel.h"

#import "JCRoutesViewController.h"
#import "JCRoutesListViewModel.h"
#import "JCRouteCaptureViewController.h"
#import "JCNotificationManager.h"
#import "MBProgressHUD.h"

#import "JCUserView.h"
#import <QuartzCore/QuartzCore.h>
#import "JCWelcomeViewController.h"

#import "Flurry.h"
#import <GBDeviceInfo/GBDeviceInfo.h>
#import <GSKeychain/GSKeychain.h>

@interface JCUserViewController ()

@end

@implementation JCUserViewController

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    [[JCLocationManager manager] setDelegate:self];
    _viewModel = [[JCUserViewModel alloc] init];
    [self update];
    return self;
}

-(void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    // User details
    JCUserView *detailsView = [[JCUserView alloc] initWithViewModel:_viewModel];
    [self.view addSubview:detailsView];
    int navBarHeight = self.navigationController.navigationBar.frame.size.height;
    [detailsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).with.offset(22);
        make.right.equalTo(self.view.mas_right).with.offset(-22);
        make.top.equalTo(self.view.mas_top).with.offset(navBarHeight + 35); // Extra 20 for status bar
        make.bottom.equalTo(detailsView.settingsButton.mas_bottom).with.offset(15);
    }];

    detailsView.settingsButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        IASKAppSettingsViewController *settingsVC = [[IASKAppSettingsViewController alloc] initWithNibName:@"IASKAppSettingsView"
                                                                                                     bundle:nil];
        settingsVC.delegate = self;
        settingsVC.showDoneButton = YES;
        settingsVC.showCreditsFooter = NO;
        UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        [self.navigationController presentViewController:settingsNav
                                                animated:YES
                                              completion:^{
                                                  NSLog(@"Settings shown");
                                              }];
        return [RACSignal empty];
    }];

    // Background map image view
    _mapView = [[MKMapView alloc] init];
    _mapView.layer.masksToBounds = NO;
    _mapView.layer.shadowOffset = CGSizeMake(0, 1);
    _mapView.layer.shadowRadius = 2;
    _mapView.layer.shadowOpacity = 0.5;
    _mapView.zoomEnabled = NO;
    _mapView.scrollEnabled = NO;
    _mapView.userInteractionEnabled = NO;
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:_mapView belowSubview:detailsView];
    [_mapView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_top);
        make.left.equalTo(self.view.mas_left);
        make.right.equalTo(self.view.mas_right);
        make.bottom.equalTo(detailsView.mas_bottom).with.offset(15);
    }];

    // Buttons
    UIColor *buttonColor = [UIColor colorWithRed:0 green:224.0/255.0 blue:184.0/255.0 alpha:1.0];
    
    // My routes button
    self.myRoutesButton = [[UIButton alloc] init];
    [self.myRoutesButton setTitle:@"My Routes" forState:UIControlStateNormal];
    [self.myRoutesButton setBackgroundColor:buttonColor];
    self.myRoutesButton.layer.cornerRadius = 8.0f;
    [self.view addSubview:self.myRoutesButton];
    
    [self.myRoutesButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_mapView.mas_bottom).with.offset(15);
        make.left.equalTo(self.view.mas_left).with.offset(22);
        make.right.equalTo(self.view.mas_right).with.offset(-22);
        make.height.equalTo(@(45));
    }];
    
    self.myRoutesButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [Flurry logEvent:@"My routes tapped"];
        JCRoutesListViewModel *routesViewModel = [[JCRoutesListViewModel alloc] init];
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [[routesViewModel loadUserRoutes] subscribeError:^(NSError *error) {
                    NSLog(@"Error loading my routes");
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                } completed:^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    NSLog(@"Got my routes");
                    if (routesViewModel.routes.count > 0) {
                        [routesViewModel setTitle:@"My Routes"];
                        JCRoutesViewController *routesController = [[JCRoutesViewController alloc] initWithViewModel:routesViewModel];
                        [self.navigationController pushViewController:routesController animated:YES];
                    } else {
                        // No routes
                        [[JCNotificationManager manager] displayInfoWithTitle:@"No Routes"
                                                                     subtitle:@"You haven't recorded any routes"
                                                                         icon:[UIImage imageNamed:@"route-icon"]];
                    }
                }];
            });
        });
        return [RACSignal empty];
    }];
    
    // Nearby routes button
    _nearbyRoutesButton = [[UIButton alloc] init];
    [_nearbyRoutesButton setTitle:@"Nearby Routes" forState:UIControlStateNormal];
    [_nearbyRoutesButton setBackgroundColor:buttonColor];
    _nearbyRoutesButton.layer.cornerRadius = 8.0f;
    [self.view addSubview:_nearbyRoutesButton];
    
    [_nearbyRoutesButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.myRoutesButton.mas_bottom).with.offset(15);
        make.left.equalTo(self.view.mas_left).with.offset(22);
        make.right.equalTo(self.view.mas_right).with.offset(-22);
        make.height.equalTo(@(45));
    }];
    
    _nearbyRoutesButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [Flurry logEvent:@"Nearby routes tapped"];
        JCRoutesListViewModel *routesViewModel = [[JCRoutesListViewModel alloc] init];
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // Do something...
            dispatch_async(dispatch_get_main_queue(), ^{
                [[routesViewModel loadNearbyRoutes] subscribeError:^(NSError *error) {
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    [[JCNotificationManager manager] displayInfoWithTitle:@"No Routes"
                                                                 subtitle:@"There are no nearby routes"
                                                                     icon:[UIImage imageNamed:@"route-icon"]];
                } completed:^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    NSLog(@"Got nearby routes");
                    if (routesViewModel.routes.count > 0) {
                        [routesViewModel setTitle:@"Nearby Routes"];
                        JCRoutesViewController *routesController = [[JCRoutesViewController alloc] initWithViewModel:routesViewModel];
                        [self.navigationController pushViewController:routesController animated:YES];
                    } else {
                        // No routes
                        [[JCNotificationManager manager] displayInfoWithTitle:@"No Routes"
                                                                     subtitle:@"There are no nearby routes"
                                                                         icon:[UIImage imageNamed:@"route-icon"]];
                    }
                }];
            });
        });
        return [RACSignal empty];
    }];
    
    _createRouteButton = [[UIButton alloc] init];
    [_createRouteButton setTitle:@"Create Route" forState:UIControlStateNormal];
    [_createRouteButton setBackgroundColor:buttonColor];
    _createRouteButton.layer.cornerRadius = 8.0f;
    [self.view addSubview:_createRouteButton];
    
    [_createRouteButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_nearbyRoutesButton.mas_bottom).with.offset(15);
        make.left.equalTo(self.view.mas_left).with.offset(22);
        make.right.equalTo(self.view.mas_right).with.offset(-22);
        make.height.equalTo(@60);
    }];

    _createRouteButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        [Flurry logEvent:@"Route capture tapped"];
        _updateOnAppear = YES;
        JCRouteCaptureViewController *captureController = [[JCRouteCaptureViewController alloc] init];
        [self.navigationController pushViewController:captureController animated:YES];
        return [RACSignal empty];
    }];

    // Nav
    [self.navigationItem setTitle:@"Profile"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setHidesBackButton:YES];
}

-(void)viewWillAppear:(BOOL)animated
{
    [[JCLocationManager manager] startUpdatingCoarse];
    if (_updateOnAppear) {
        [self update];
        _updateOnAppear = NO;
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [[[JCLocationManager manager] locationManager] stopUpdatingLocation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)update
{
    [[_viewModel loadDetails] subscribeError:^(NSError *error) {
        NSLog(@"Failed to load user");
    } completed:^{
        NSLog(@"User details loaded");
    }];
}

- (void)logout
{
    JCWelcomeViewController *welcomeController = [[JCWelcomeViewController alloc] init];
    NSArray *viewControllerStack = @[welcomeController];
    [self.navigationController setViewControllers:viewControllerStack];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - JCLocationManagerDelegate methods

- (void)didUpdateLocations:(NSArray *)locations
{
    NSLog(@"Got locations in user overview");
    CLLocation *location = locations[0];
    CLLocationCoordinate2D loc = location.coordinate;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(loc, 2500, 2500);
    [_mapView setRegion:region animated:YES];
}

#pragma mark - IASKSettingsDelegate methods

- (NSString *)settingsViewController:(id<IASKViewController>)settingsViewController mailComposeBodyForSpecifier:(IASKSpecifier *)specifier
{
    GBDeviceDetails *deviceDetails = [GBDeviceInfo
                                      deviceDetails];

    NSString *iosVersion = [NSString stringWithFormat:@"%lu.%lu",
                            (unsigned long)deviceDetails.majoriOSVersion,
                            (unsigned long)deviceDetails.minoriOSVersion];
    return [NSString stringWithFormat:@"**********\niOS Version: %@\nDevice: %@\n**********", iosVersion, deviceDetails.modelString];
}

-(void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    [self.navigationController dismissViewControllerAnimated:YES
                                                  completion:^{
                                                      NSLog(@"Dismissed settings");
                                                  }];
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier *)specifier
{
    if ([[specifier key] isEqualToString:@"logout"])
    {
        [[GSKeychain systemKeychain] removeAllSecrets];
        [self.navigationController dismissViewControllerAnimated:NO
                                                      completion:^{
                                                          NSLog(@"Dismissed settings");
                                                      }];
        [self logout];
    }
}

@end
