//
//  TVNetworkClient.h
//  TwitterVoid
//
//  Created by Hellier on 17.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accounts/Accounts.h>

@interface TVNetworkClient : NSObject
@property (strong,nonatomic) ACAccount *twitterAccount;
-(RACSignal*)fetchTweetsParams:(NSDictionary*)params;
+(instancetype)shared;
@end
