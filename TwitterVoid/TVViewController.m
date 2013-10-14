//
//  TVViewController.m
//  TwitterVoid
//
//  Created by Hellier on 14.10.13.
//  Copyright (c) 2013 void. All rights reserved.
//

#import "TVViewController.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import "TVTweetCell.h"
#import "UIScrollView+SVInfiniteScrolling.h"


static NSString *twitter_user = @"SpaceX";

typedef enum{
    TVViewControllerSortOrderDate,
    TVViewControllerSortOrderAlpha

} TVViewControllerSortOrder;

@interface TVViewController ()<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sortControl;

@property (strong,nonatomic) ACAccount *account;
@property (strong,nonatomic) NSArray *tweets;
@property (strong,nonatomic) NSArray *filteredTweets;
@property (strong,nonatomic) NSArray *sortedTweets;

@property (assign,nonatomic) TVViewControllerSortOrder sortOrder;
@end

@implementation TVViewController


-(void)showAlertWithError:(NSError*)error
{
    UIAlertView *alert = [[UIAlertView alloc] init];
    alert.message = error.localizedDescription;
    alert.cancelButtonIndex = [alert addButtonWithTitle:@"Continue"];
    [alert show];
}

-(void)showNoAccountsFound
{
    UIAlertView *alert = [[UIAlertView alloc] init];
    alert.message = @"No twitter Accounts found";
    alert.cancelButtonIndex = [alert addButtonWithTitle:@"Continue"];
    [alert show];
}


-(NSDictionary*)tweetForIndexPath:(NSIndexPath*)indexPath
{
    if (self.searchBar.text.length > 0)
    {
        return self.filteredTweets[indexPath.row];
    }

    return self.sortedTweets[indexPath.row];
}

-(float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *tweet = [self tweetForIndexPath:indexPath];
    return [TVTweetCell heightForTweet:tweet forWidth:self.tableView.bounds.size.width];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.searchBar.text.length > 0 ? self.filteredTweets.count: self.sortedTweets.count;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TVTweetCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TVTweetCell"];
    cell.tweet = [self tweetForIndexPath:indexPath];
    [cell configureCell];
    return cell;
}


-(void)addInfinieScrolling
{
    __weak TVViewController *ctrl = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        [ctrl fetchPreviousTweets];
    }];
}

-(void)fetchTimeline
{
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com"
                  @"/1.1/statuses/user_timeline.json"];
    id params = @{@"screen_name" : twitter_user ,@"trim_user" : @"1"};
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                        requestMethod:SLRequestMethodGET
                                                  URL:url parameters:params];

    req.account = self.account;


    [req performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {

        NSError *jsonError = nil;
        NSArray *tweets = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&jsonError];
        dispatch_async(dispatch_get_main_queue(), ^{

            self.tweets = tweets;
            [self sortTweetsHandler:^{
                [self addInfinieScrolling];
                [self.tableView reloadData];
            }];
        });
    }];
}


-(void)fetchPreviousTweets
{
    NSDictionary *last_tweet = self.tweets.lastObject;
    NSNumber *last_id = last_tweet[@"id"];
    if (last_id == nil)
    {
        return;
    }

    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com"
                  @"/1.1/statuses/user_timeline.json"];
    id params = @{@"screen_name" : twitter_user ,@"trim_user" : @"1", @"max_id": last_id.stringValue};
    SLRequest *req = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                        requestMethod:SLRequestMethodGET
                                                  URL:url parameters:params];

    req.account = self.account;

    [req performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {

        NSError *jsonError = nil;
        NSArray *tweets = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&jsonError];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *last_tweet = self.tweets.lastObject;
            NSString *current_last_id = last_tweet[@"id"];
            if (![current_last_id isEqual:last_id] )
            {
                return; // seems it is alread loaded
            }

            if (tweets.count <= 1)
            {
                self.tableView.infiniteScrollingView.enabled = NO;
                return;
            }

            self.tweets = [self.tweets arrayByAddingObjectsFromArray:[tweets subarrayWithRange:NSMakeRange(1, tweets.count - 1)]];
            [self sortTweetsHandler:^{
                [self.tableView.infiniteScrollingView stopAnimating];
                [self.tableView reloadData];
            }];
        });
    }];
}


-(void)requestAccess
{
    ACAccountStore *store = [[ACAccountStore alloc] init];
    ACAccountType *account_type = [store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [store requestAccessToAccountsWithType:account_type options:nil completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                [self showAlertWithError:error];
                return;
            }

            ACAccount *account = [store accountsWithAccountType:account_type].lastObject;
            if (account == nil)
            {
                [self showNoAccountsFound];
                return;
            }

            self.account = account;
            
            [self fetchTimeline];
        });
    }];
}

-(void)sortTweetsHandler:(void(^)())handler
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"EEE LLL d HH:mm:ss Z yyyy"];
    [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];

    NSComparisonResult(^date_comparator)(id obj1, id obj2) = ^(NSDictionary *tweet1, NSDictionary *tweet2){
        NSDate *date1 = [formatter dateFromString:tweet1[@"created_at"]];
        NSDate *date2 = [formatter dateFromString:tweet2[@"created_at"]];
        return -[date1 compare:date2];
    };


    NSComparisonResult(^alpha_comparator)(id obj1, id obj2) = ^(NSDictionary *tweet1, NSDictionary *tweet2) {
        return [[tweet1[@"text"] substringToIndex:1] compare:[tweet2[@"text"] substringToIndex:1]];
    };

    TVViewControllerSortOrder order = self.sortOrder;
    NSArray *tweets_list = self.tweets;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{

        NSArray *res = nil;
        if (order == TVViewControllerSortOrderAlpha)
        {
            res = [tweets_list sortedArrayUsingComparator:alpha_comparator];
        } else
        {
            res = [tweets_list sortedArrayUsingComparator:date_comparator];
        }


        dispatch_async(dispatch_get_main_queue(), ^{
            self.sortedTweets = res;

            if (self.searchBar.text.length > 0)
            {
                [self filterTweets:handler];
            }
            else
            {
                handler();
            }

        });

    });
}

-(void)filterTweets:(void(^)())handler
{
    NSArray *tweets_list = self.sortedTweets;

    NSString *search_term = self.searchBar.text.lowercaseString;
    if (search_term.length == 0)
    {
        return;
    }

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableArray *res = [NSMutableArray array];


        for (NSDictionary *tweet in tweets_list)
        {
            NSString *tweet_text = [tweet[@"text"] lowercaseString];
            if ([tweet_text rangeOfString:search_term].location != NSNotFound)
            {
                [res addObject:tweet];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.filteredTweets = res;
            handler();
        });

    });
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    if (searchBar.text.length == 0)
    {
        self.filteredTweets = nil;
        [self.tableView reloadData];
    }
    else
    {
        [self filterTweets:^{
            [self.tableView reloadData];
        }];
    }

    [searchBar resignFirstResponder];
}

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (searchBar.text.length == 0)
    {
        self.filteredTweets = nil;
        [self.tableView reloadData];
    }
    else
    {
        [self filterTweets:^{
            [self.tableView reloadData];
        }];
    }
}

-(IBAction)sortOrderChanged:(id)sender
{
    self.sortOrder = self.sortControl.selectedSegmentIndex == 0 ? TVViewControllerSortOrderDate : TVViewControllerSortOrderAlpha;

    [self sortTweetsHandler:^{
        [self.tableView reloadData];
    }];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.searchBar resignFirstResponder];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self requestAccess];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
