//
//  TVTweet.m
//  TwitterVoid
//
//  Created by Hellier on 17.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import "TVTweet.h"

@implementation TVTweet

+(NSDateFormatter*)dateFormatter
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"EEE LLL d HH:mm:ss Z yyyy"];
    [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    return formatter;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"createdAt": @"created_at",
             @"text": @"text",
             @"tweetId": @"id"
             };
}

+ (NSValueTransformer *)createdAtJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [self.dateFormatter dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [self.dateFormatter stringFromDate:date];
    }];
}

-(NSString*)hashTag
{
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"#(\\w+)"
                                  options:0
                                  error:nil];

    NSTextCheckingResult *res = [regex matchesInString:self.text options:0 range:NSMakeRange(0, self.text.length)].lastObject;

    if (res)
    {
        NSRange range = NSMakeRange(res.range.location + 1, res.range.length -1);
        return [self.text substringWithRange:range];
    }
    return nil;
}



+(NSArray*)sortedByDate:(NSArray*)tweets
{
    NSComparisonResult(^date_comparator)(TVTweet *tweet1, TVTweet *tweet2) = ^(TVTweet *tweet1, TVTweet *tweet2) {
        return -[tweet1.createdAt compare:tweet2.createdAt];
    };

    return [tweets sortedArrayUsingComparator:date_comparator];
}


+(NSArray*)sortedByApha:(NSArray*)tweets
{
    NSComparisonResult(^alpha_comparator)(TVTweet *tweet1, TVTweet *tweet2) = ^(TVTweet *tweet1, TVTweet *tweet2) {
        return [[tweet1.text substringToIndex:1] compare:[tweet2.text substringToIndex:1]];
    };

    return [tweets sortedArrayUsingComparator:alpha_comparator];
}
@end
