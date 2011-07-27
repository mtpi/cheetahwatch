//
//  GSMUtils.h
//  CheetahWatch
//
//  Created by Matteo Pillon on 27/07/11.
//  Copyright 2011 Matteo Pillon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define GSMNumberTypeMask          0x70
typedef enum {
    GSMNumberTypeUnknown         = 0x00,
    GSMNumberTypeInternational   = 0x10,
    GSMNumberTypeNational        = 0x20,
    GSMNumberTypeNetworkSpecific = 0x30,
    GSMNumberTypeSubscriber      = 0x40,
    GSMNumberTypeAlphanumeric    = 0x50,
    GSMNumberTypeAbbreviated     = 0x60,
    GSMNumberTypeReserved        = 0x70,
} GSMNumberType;

// parse timestamp, encoded in swapped nibbles
// 0x99 0x20 0x21 0x50 0x75 0x03 0x21 means 12. Feb 1999 05:57:30 GMT+3
NSDate *parseTimeStamp(NSData *data)
{
    const UInt8 *bytes = [data bytes];
    const UInt8 *maxByte = [data bytes]+[data length];
    NSMutableString *dateString = [NSMutableString stringWithCapacity:25];
    char *tmpstr;
    // year
    [dateString appendString:@"20"];
    asprintf(&tmpstr, "%02x", *bytes);
    [dateString appendFormat:@"%c%c", *(tmpstr+1), *tmpstr];
    if (++bytes >= maxByte)
        return nil;
    //month
    [dateString appendString:@"-"];
    asprintf(&tmpstr, "%02x", *bytes);
    [dateString appendFormat:@"%c%c", *(tmpstr+1), *tmpstr];
    if (++bytes >= maxByte)
        return nil;
    //day
    [dateString appendString:@"-"];
    asprintf(&tmpstr, "%02x", *bytes);
    [dateString appendFormat:@"%c%c", *(tmpstr+1), *tmpstr];
    if (++bytes >= maxByte)
        return nil;
    //hour
    [dateString appendString:@" "];
    asprintf(&tmpstr, "%02x", *bytes);
    [dateString appendFormat:@"%c%c", *(tmpstr+1), *tmpstr];
    if (++bytes >= maxByte)
        return nil;
    //minute
    [dateString appendString:@":"];
    asprintf(&tmpstr, "%02x", *bytes);
    [dateString appendFormat:@"%c%c", *(tmpstr+1), *tmpstr];
    if (++bytes >= maxByte)
        return nil;
    //second
    [dateString appendString:@":"];
    asprintf(&tmpstr, "%02x", *bytes);
    [dateString appendFormat:@"%c%c", *(tmpstr+1), *tmpstr];
    if (++bytes >= maxByte)
        return nil;
    //timezone
    UInt8 timezone = *bytes;
    if (timezone&0x80) {
        [dateString appendString:@" -"];
        timezone = timezone&0x7F;
    } else {
        [dateString appendString:@" +"];
    }
    [dateString appendFormat:@"%02d", timezone*15/60];
    [dateString appendFormat:@"%02d", timezone*15%60];
    
    return [NSDate dateWithString:dateString];
}

// get pdu 7bit packed string
NSString *unpack7BitString(NSData *data)
{
    NSMutableString *text = [NSMutableString stringWithCapacity:160];
    const UInt8 *bytes = [data bytes];
    const UInt8 *maxBytes = [data bytes]+[data length];
    UInt8 nextCharMask = 1<<7;
    UInt8 shiftingPositions = 0;
    UInt8 curChar = 0;
    UInt8 nextChar = 0;
    for (; bytes<maxBytes; bytes++) {
        curChar = nextChar | ((*bytes & (nextCharMask^0xFF))<<shiftingPositions);
        nextChar = (*bytes & nextCharMask) >> 7-shiftingPositions;
        [text appendFormat:@"%c", curChar];
        if (shiftingPositions==6) {
            nextCharMask = 1<<7;
            shiftingPositions = 0;
            curChar = 0;
            [text appendFormat:@"%c", nextChar];
            nextChar = 0;
        } else {
            nextCharMask = (nextCharMask>>1) | (1<<7);
            shiftingPositions++;
        }
    }
    if (nextChar)
        [text appendFormat:@"%c", nextChar];
    return text;
}

// get pdu swapped semi-octets phone number
NSString *phoneNumber(NSData *data, BOOL international)
{
    NSMutableString *number = [NSMutableString stringWithCapacity:20];
    const UInt8 *bytes = [data bytes];
    const UInt8 *maxBytes = [data bytes]+[data length];
    if (international) {
        [number appendString:@"+"];
    }
    for (; bytes<maxBytes; bytes++) {
        char *tmpstr;
        asprintf(&tmpstr, "%02x", *bytes);
        if (*tmpstr == 'F') {
            [number appendFormat:@"%c",*(tmpstr+1)];
            break;
        } else {
            [number appendFormat:@"%c%c",*(tmpstr+1),*tmpstr];
        }
    }
    return number;
}
