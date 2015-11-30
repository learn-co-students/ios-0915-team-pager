//
//  MyAlbumsViewController.h
//  VinylMap
//
//  Created by Haaris Muneer on 11/19/15.
//  Copyright © 2015 Toaster. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FirebaseUI/FirebaseUI.h>
#import <Firebase/Firebase.h>

@interface MyAlbumsViewController : UIViewController

@property (strong, nonatomic) Firebase *firebaseRef;
@property (strong, nonatomic) FirebaseCollectionViewDataSource *dataSource;

@end
