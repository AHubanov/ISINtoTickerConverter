//
//  ViewController.m
//  ISINConverter
//
//  Created by ALIAKSANDR HUBANAU on 30.10.21.
//

#import "ViewController.h"

@interface ViewController()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *isinDictionary;
@property (nonatomic, strong) NSArray<NSString *> *isins;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableString *result;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.isinDictionary = [NSMutableDictionary<NSString *, NSString *> new];
    self.url = [NSURL URLWithString:@"https://api.openfigi.com/v3/mapping"];
    self.result = [NSMutableString new];
    
}

- (IBAction)converISINS:(id)sender {
    
    NSURL *resourceUrl = [[NSBundle mainBundle] URLForResource:@"ISIN_LIST" withExtension:@"txt"];
    NSString *contentString = [NSString stringWithContentsOfURL:resourceUrl encoding:NSUTF8StringEncoding error:nil];
    self.isins = [contentString componentsSeparatedByString:@"\n"];
    
    [self requestWithIndex:0];
}

static BOOL isSecondAttempt = NO;

- (void)requestWithIndex:(int)index {
    NSLog(@"[ISIN-TICKER][%i] requested", index);
    __block int nextIndex = index + 1;
    NSString *isin = self.isins[index];
 
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    request.HTTPMethod = @"POST";
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@[@{@"idType": @"ID_ISIN", @"idValue" : isin}] options:NSJSONWritingPrettyPrinted error:nil];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error == nil) {
                id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
                if ([object isKindOfClass:NSArray.class]) {
                    isSecondAttempt = NO;
                    NSDictionary *values = object[0][@"data"][0];
                    NSLog(@"[ISIN-TICKER][%i] %@,%@,%@,%@", nextIndex - 1, isin, values[@"exchCode"], values[@"name"], values[@"ticker"]);
                    [self.result appendFormat:@"[ISIN-TICKER][%i] %@,%@,%@,%@\n", nextIndex - 1, isin, values[@"exchCode"], values[@"name"], values[@"ticker"]];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        if (nextIndex < self.isins.count) {
                            [self saveToFile];
                            [self requestWithIndex:nextIndex];
                        } else {
                            [self saveToFile];
                        }
                        
                    });
                } else {
                    NSLog(@"[ISIN-TICKER] other structure %@", object);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [self saveToFile];
                        if (!isSecondAttempt) {
                            isSecondAttempt = YES;
                            [self requestWithIndex:nextIndex - 1];
                        } else {
                            [self requestWithIndex:nextIndex];
                        }
                    });
                }
            } else {
                NSLog(@"[ISIN-TICKER] request error %@", error);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    if (nextIndex < self.isins.count) {
                        [self saveToFile];
                        
                        if (!isSecondAttempt) {
                            isSecondAttempt = YES;
                            [self requestWithIndex:nextIndex - 1];
                        } else {
                            [self requestWithIndex:nextIndex];
                        }
                    }
                });
            }
    }];
    [task resume];
}

- (void)saveToFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"tickers.txt"];
    [self.result writeToFile:dataPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"[ISIN-TICKER] file path = %@", dataPath);
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

@end
