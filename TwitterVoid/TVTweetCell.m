//
//  TVTweetCell.m
//  TwitterVoid
//
//  Created by Hellier on 14.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import "TVTweetCell.h"
#import "UIImageView+WebCache.h"
#import "EXTScope.h"

@interface TVTweetCell()
@property (weak, nonatomic) IBOutlet UIImageView *tweetImageView;
@property (weak, nonatomic) IBOutlet UILabel *tweetLabel;
@end

@implementation TVTweetCell

-(void)awakeFromNib
{
    [super awakeFromNib];
    RAC(self, tweetLabel.text) = RACObserve(self, tweet.text);

    @weakify(self);
    [RACObserve(self, tweet.flickrUrl) subscribeNext:^(NSURL *url) {
        @strongify(self);
        [self.tweetImageView setImageWithURL:url];
    }];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    self.tweetLabel.preferredMaxLayoutWidth = self.superview.bounds.size.width - (65 + 10);
}


+(float)heightForTweet:(TVTweet*)tweet forWidth:(float)width
{
    CGSize constraints = CGSizeMake(width - (65+10), FLT_MAX);
    CGSize size = [tweet.text sizeWithFont:[UIFont systemFontOfSize:17]
                             constrainedToSize:constraints
                                 lineBreakMode:NSLineBreakByWordWrapping];
    size.height = ceilf(size.height + 5 + 10);

    return MAX(size.height, 62);
}

@end
