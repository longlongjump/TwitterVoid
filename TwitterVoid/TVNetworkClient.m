//
//  TVNetworkClient.m
//  TwitterVoid
//
//  Created by Hellier on 17.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import "TVNetworkClient.h"
#import "FlickrKit.h"
#import <Social/Social.h>

@implementation TVNetworkClient
+(instancetype)shared
{
    static TVNetworkClient *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[TVNetworkClient alloc] init];
    });
    return shared;
}

-(id)init
{
    self = [super init];
    return self;
}

-(RACSignal*)fetchImageForTag:(NSString*)tag
{
    RACSubject *subject = [RACSubject subject];
    [[FlickrKit sharedFlickrKit] call:@"flickr.photos.search" args:@{@"tags": tag, @"per_page": @"1", @"api_key" : [FlickrKit sharedFlickrKit].apiKey} maxCacheAge:FKDUMaxAgeOneHour completion:^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                NSLog(@"%@", error);
                [subject sendNext:NSNull.null];
                return;
            }

            id photo = [response[@"photos"][@"photo"] lastObject];
            if (photo == nil)
            {
                [subject sendCompleted];
                return;
            }

            NSURL *url = [[FlickrKit sharedFlickrKit] photoURLForSize:FKPhotoSizeSmall240 fromPhotoDictionary:photo];
            [subject sendNext:url];
            [subject sendCompleted];
        });
    }];

    return subject;
}


-(void)processTweetsForImages:(NSArray*)tweets
{
    [tweets enumerateObjectsUsingBlock:^(TVTweet *tweet, NSUInteger idx, BOOL *stop) {
        if (tweet.hashTag.length == 0)
        {
            return;
        }

        RAC(tweet, flickrUrl) = [self fetchImageForTag:tweet.hashTag];
    }];
}


-(RACSignal*)fetchTweetsParams:(NSDictionary*)params
{
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com"
                  @"/1.1/statuses/user_timeline.json"];
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                        requestMethod:SLRequestMethodGET
                                                  URL:url parameters:params];

    req.account = self.twitterAccount;

    RACReplaySubject *subject = [RACReplaySubject subject];

    [req performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {

        if (error)
        {
            [subject sendError:error];
            return;
        }

        NSError *jsonError = nil;
        NSArray *tweets_array = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&jsonError];

        if (jsonError)
        {
            [subject sendError:error];
            return;
        }

        if (params[@"max_id"] && tweets_array.count >= 1)
        {
            tweets_array = [tweets_array subarrayWithRange:NSMakeRange(1, tweets_array.count - 1)];
        }

        NSMutableArray *tweets = [NSMutableArray array];
        [tweets_array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            id res = [MTLJSONAdapter modelOfClass:TVTweet.class fromJSONDictionary:obj error:nil];
            [tweets addObject:res];
        }];


        [subject sendNext:tweets];
        [subject sendCompleted];
    }];


    [subject subscribeNext:^(NSArray *tweets) {
        [self processTweetsForImages:tweets];
    }];

    return subject;
}
@end
