//
//  TVTweet.h
//  TwitterVoid
//
//  Created by Hellier on 17.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import "Mantle.h"

@interface TVTweet : MTLModel<MTLJSONSerializing>
@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSNumber *tweetId;
@property (strong, nonatomic) NSDate *createdAt;

@property (strong,nonatomic) NSURL *flickrUrl;

@property (readonly,nonatomic) NSString *hashTag;

+(NSArray*)sortedByDate:(NSArray*)tweets;
+(NSArray*)sortedByApha:(NSArray*)tweets;

@end
