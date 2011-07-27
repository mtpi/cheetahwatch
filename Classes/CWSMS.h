//
//  CWSMS.h
//  CheetahWatch
//
//  Created by Matteo Pillon on 26/07/11.
//  Copyright 2011 Matteo Pillon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CWSMS : NSObject {
    NSInteger index;
    NSInteger stat;
    NSInteger length;
    NSString *sender;
    NSString *text;
    NSString *smsc;
    NSDate *timestamp;
    NSData *pdu;
}

@property(assign) NSInteger index;
@property(assign) NSInteger stat;
@property(assign) NSInteger length;
@property(retain) NSString *sender;
@property(retain) NSString *text;
@property(retain) NSString *smsc;
@property(retain) NSDate *timestamp;
@property(retain) NSData *pdu;


- (BOOL)validPDU;
- (void)processPDU;

@end
