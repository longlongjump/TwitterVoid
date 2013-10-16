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
#import "TVNetworkClient.h"
#import "FlickrKit.h"


static NSString *twitter_user = @"icicorg";

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

@property (strong,nonatomic) NSMutableDictionary *tweetImageUrls;

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


-(TVTweet*)tweetForIndexPath:(NSIndexPath*)indexPath
{
    if (self.searchBar.text.length > 0)
    {
        return self.filteredTweets[indexPath.row];
    }

    return self.sortedTweets[indexPath.row];
}

-(float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TVTweet *tweet = [self tweetForIndexPath:indexPath];
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
    return cell;
}


-(void)addInfinieScrolling
{
    __weak TVViewController *ctrl = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        [ctrl fetchPreviousTweets];
    }];
}


-(void)fetchPreviousTweets
{
    TVTweet *last_tweet = self.tweets.lastObject;

    RACSignal *signal = [TVNetworkClient.shared fetchTweetsParams:@{@"screen_name" : twitter_user ,@"trim_user" : @"1", @"max_id": last_tweet.tweetId.stringValue}];

    [signal subscribeNext:^(NSArray *tweets) {
        [self.tableView.infiniteScrollingView stopAnimating];
        self.tableView.infiniteScrollingView.enabled = tweets.count > 0;
        self.tweets = [self.tweets arrayByAddingObjectsFromArray:tweets];
        [self sortTweetsHandler:^{
            [self.tableView reloadData];
        }];

    }];
}


-(void)fetchTweets
{
    RACSignal *sig = [TVNetworkClient.shared fetchTweetsParams:@{@"screen_name" : twitter_user ,@"trim_user" : @"1"}];

    [sig subscribeNext:^(id x) {
        self.tweets = x;
        [self sortTweetsHandler:^{
            [self.tableView reloadData];
            [self addInfinieScrolling];
        }];
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

            TVNetworkClient.shared.twitterAccount = account;

            [self fetchTweets];
        });
    }];
}


-(void)sortTweetsHandler:(void(^)())handler
{
    TVViewControllerSortOrder order = self.sortOrder;
    NSArray *tweets_list = self.tweets;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{

        NSArray *res = nil;
        if (order == TVViewControllerSortOrderAlpha)
        {
            res = [TVTweet sortedByApha:tweets_list];
        } else
        {
            res = [TVTweet sortedByDate:tweets_list];
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

        NSArray *res = [tweets_list filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TVTweet *tweet, NSDictionary *b) {
            return [tweet.text.lowercaseString rangeOfString:search_term].location != NSNotFound;
        }]];

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
