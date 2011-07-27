//
//  CWSMSContactsController.h
//  CheetahWatch
//
//  Created by Matteo Pillon on 26/07/11.
//  Copyright 2011 Matteo Pillon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CWModel;

@interface CWSMSContactsController : NSWindowController {
    CWModel *model;
}

@property(retain) CWModel *model;


@end
