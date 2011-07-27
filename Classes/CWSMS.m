//
//  CWSMS.m
//  CheetahWatch
//
//  Created by Matteo Pillon on 26/07/11.
//  Copyright 2011 Matteo Pillon. All rights reserved.
//

// This implementation uses PDU for max flexibility :)
// Followed very useful quick specs on http://www.dreamfabric.com/sms/

#import "CWSMS.h"
#import "GSMUtils.h"

@implementation CWSMS

@synthesize index, stat, length, pdu, sender, text, smsc, timestamp;

- (void) reset
{
    self.sender = nil;
    self.text = nil;
    self.smsc = nil;
    self.timestamp = nil;
}

- (void) dealloc
{
    [pdu release];
    [sender release];
    [text release];
    [smsc release];
    [timestamp release];
    [super dealloc];
}

- (BOOL)validPDU
{
    // check declared length
    const UInt8 *pduBytes = [pdu bytes];
    UInt8 smscLength = *pduBytes;
    NSInteger totalLength = 1 + smscLength + length;
    return [pdu length] == totalLength;
}

- (void)processPDU
{
    if (!pdu)
        return;
    
    [self reset];
    
#ifdef DEBUG_SMS
    NSLog(@"PDU: %@", pdu);
#endif
    const UInt8 *pduBytes = [pdu bytes];
    const UInt8 *maxByte = [pdu bytes]+[pdu length];
    
    UInt8 smscLength = *pduBytes;
    if (++pduBytes>=maxByte)
        return;
    
    UInt8 typeOfSmscAddress = *pduBytes;
    if (++pduBytes>=maxByte)
        return;
    
    if (pduBytes+smscLength-1 >= maxByte)
        return;
    NSData *smscData = [NSData dataWithBytes:pduBytes length:smscLength-1];
    if ((typeOfSmscAddress&GSMNumberTypeMask) == GSMNumberTypeAlphanumeric) {
        self.smsc = unpack7BitString(smscData);
    } else if ((typeOfSmscAddress&GSMNumberTypeMask) == GSMNumberTypeInternational) {
        self.smsc = phoneNumber(smscData, YES);
    } else {
        self.smsc = phoneNumber(smscData, NO);
    }
#ifdef DEBUG_SMS
    NSLog(@"SMSC: %@", self.smsc);
#endif
    pduBytes += smscLength-1;
    
    // TODO: parse smsDeliver, maybe TP-MMS is interesting for multiple messages...
    UInt8 smsDeliver = *pduBytes;
#ifdef DEBUG_SMS
    if (smsDeliver != 0x04)
        NSLog(@"smsDeliver!=0x04, smsDeliver: %d", smsDeliver);
#endif
    if (++pduBytes>=maxByte)
        return;
    
    UInt8 senderAddressLength = *pduBytes;
#ifdef DEBUG_SMS
    NSLog(@"senderAddressLength: 0x%02X", senderAddressLength);
#endif
    if (++pduBytes>=maxByte)
        return;
    
    UInt8 typeOfSenderAddress = *pduBytes;
#ifdef DEBUG_SMS
    NSLog(@"typeOfSenderAddress: 0x%02X", typeOfSenderAddress);
#endif
    if (++pduBytes>=maxByte)
        return;
    
    if (pduBytes+(senderAddressLength+1)/2 >= maxByte)
        return;
    UInt8 senderAddressBytes = (senderAddressLength+1)/2;
    NSData *senderData = [NSData dataWithBytes:pduBytes length:senderAddressBytes];
    if ((typeOfSenderAddress&GSMNumberTypeMask) == GSMNumberTypeAlphanumeric) {
        self.sender = unpack7BitString(senderData);        
    } else if ((typeOfSenderAddress&GSMNumberTypeMask) == GSMNumberTypeInternational) {
        self.sender = phoneNumber(senderData, YES);
    } else {
        self.sender = phoneNumber(senderData, NO);
    }
#ifdef DEBUG_SMS
    NSLog(@"SENDER: %@", self.sender);
#endif
    pduBytes += (senderAddressLength+1)/2;
    
    // TODO: parse protocolIdentifier
    UInt8 protocolIdentifier = *pduBytes;
#ifdef DEBUG_SMS
    NSLog(@"protocolIdentifier: 0x%02X", protocolIdentifier);
#endif
    if (++pduBytes>=maxByte)
        return;
    
    // TODO: parse dataCodingScheme
    UInt8 dataCodingScheme = *pduBytes;
#ifdef DEBUG_SMS
    NSLog(@"dataCodingScheme: 0x%02X", dataCodingScheme);
#endif
    if (++pduBytes>=maxByte)
        return;
    
    self.timestamp = parseTimeStamp([NSData dataWithBytes:pduBytes length:7]);
#ifdef DEBUG_SMS
    NSLog(@"TIMESTAMP: %@", self.timestamp);
#endif
    if ((pduBytes+=7)>=maxByte)
        return;
    
    UInt8 userDataLength = *pduBytes;
#ifdef DEBUG_SMS
    NSLog(@"userDataLength: %d", userDataLength);
#endif
    if (++pduBytes>=maxByte)
        return;
    
    if (maxByte-pduBytes<=0)
        return;
    // TP-UD, message content finally :)
    self.text = unpack7BitString([NSData dataWithBytes:pduBytes length:maxByte-pduBytes]);
#ifdef DEBUG_SMS
    NSLog(@"TEXT: %@", self.text);
#endif
    
    // pdu not necessary anymore
    self.pdu = nil;
}

@end
