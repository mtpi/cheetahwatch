//
//  CWSMSContactsController.m
//  CheetahWatch
//
//  Created by Matteo Pillon on 26/07/11.
//  Copyright 2011 Matteo Pillon. All rights reserved.
//

#import "CWSMSContactsController.h"
//#import "CWModel.h"

@implementation CWSMSContactsController

@synthesize model;

- (void)dealloc
{
    [model release];
    [super dealloc];
}

- (void)showWindow:(id)sender
{
    [[self window] display];
    [[self window] makeKeyAndOrderFront: self];
    [NSApp activateIgnoringOtherApps:YES];
}

@end
