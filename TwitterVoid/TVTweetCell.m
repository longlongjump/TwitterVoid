//
//  TVTweetCell.m
//  TwitterVoid
//
//  Created by Hellier on 14.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import "TVTweetCell.h"
#import "UIImageView+WebCache.h"

@interface TVTweetCell()
@property (weak, nonatomic) IBOutlet UIImageView *tweetImageView;
@property (weak, nonatomic) IBOutlet UILabel *tweetLabel;
@end

@implementation TVTweetCell

-(NSString*)imageUrl
{
    for (NSDictionary *media in  self.tweet[@"entities"][@"media"])
    {
        if ([media[@"type"] isEqualToString:@"photo"])
        {
            return media[@"media_url"];
        }
    }
    return nil;
}


-(void)configureCell
{
    self.tweetLabel.text = self.tweet[@"text"];
    NSString *image_url = [self imageUrl];
    [self.tweetImageView setImageWithURL:[NSURL URLWithString:image_url]];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.tweetLabel.preferredMaxLayoutWidth = self.superview.bounds.size.width - (65 + 10);
}


+(float)heightForTweet:(NSDictionary*)tweet forWidth:(float)width
{
    CGSize constraints = CGSizeMake(width - (65+10), FLT_MAX);
    CGSize size = [tweet[@"text"] sizeWithFont:[UIFont systemFontOfSize:17]
                             constrainedToSize:constraints
                                 lineBreakMode:NSLineBreakByWordWrapping];
    size.height = ceilf(size.height + 5 + 10);

    return MAX(size.height, 62);
}

@end
