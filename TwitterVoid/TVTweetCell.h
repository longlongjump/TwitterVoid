//
//  TVTweetCell.h
//  TwitterVoid
//
//  Created by Hellier on 14.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TVTweetCell : UITableViewCell

@property (strong,nonatomic) TVTweet *tweet;

+(float)heightForTweet:(TVTweet*)tweet forWidth:(float)width;
@end
