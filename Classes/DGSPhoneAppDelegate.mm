//
//  DGSPhoneAppDelegate.m
//  DGSPhone
//
//  Created by Justin Weiss on 6/1/10.
//  Copyright Justin Weiss 2010. All rights reserved.
//

#import "DGSPhoneAppDelegate.h"
#import "CurrentGamesController.h"
#import "FuegoBoard.h"

#ifdef HOCKEY
#import "BWHockeyManager.h"
#endif

#ifdef LOG_URL
#import "ASIFormDataRequest.h"
#endif

#define THROTTLE_RATE 5*60 // 5 minutes

@implementation DGSPhoneAppDelegate

@synthesize window;
@synthesize viewController;
@synthesize blackStone;
@synthesize whiteStone;
@synthesize boardImage;
@synthesize messageOff;
@synthesize messageOn;
@synthesize logFile;
@synthesize nextRefreshTime;
@synthesize database;

#ifdef LOG_URL
- (void)uploadLogFile
{
    NSURL *url = [NSURL URLWithString:LOG_URL];
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];

    NSString *logFilePath = [self logFilePath];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {

        NSFileHandle *myHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self logFilePath]];
        NSData *data = [myHandle readDataToEndOfFile];
        NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        [request setPostValue:body forKey:@"body"];
        [request setPostValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:@"udid"];
        [body release];
        
        [request setCompletionBlock:^{
            NSFileHandle *myHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self logFilePath]];
            [myHandle truncateFileAtOffset:0];
            if (self.logFile) {
                [self.logFile seekToFileOffset:0];
            }
        }];
        [request setFailedBlock:^{
        }];
        [request startAsynchronous];
    }
}
#endif

#pragma mark -
#pragma mark Application lifecycle

- (NSString *)logFilePath {
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([paths count] > 0) {
		return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"dgs-debug.log"];
	}
	return nil;
}

#ifdef LOGGING
- (void)setupLogFile {
	NSString *logFilePath = [self logFilePath];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {
		[[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
	}
	NSFileHandle *myHandle = [NSFileHandle fileHandleForUpdatingAtPath:[self logFilePath]];
	[myHandle seekToEndOfFile];
	
	self.logFile = myHandle;
	JWLog("Writing to log file at %@", [self logFilePath]);
}
#endif

-(void) checkAndCreateDatabase {
	// Check if the SQL database has already been saved to the users phone, if not then copy it over
	BOOL success;
    
	NSString *databaseName = @"dgs.sqlite";
    
	// Get the path to the documents directory and append the databaseName
	NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir = [documentPaths objectAtIndex:0];
	NSString *databasePath = [documentsDir stringByAppendingPathComponent:databaseName];

	// Create a FileManager object, we will use this to check the status
	// of the database and to copy it over if required
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	// Check if the database has already been created in the users filesystem
	success = [fileManager fileExistsAtPath:databasePath];
    
	if (!success) {    
        // If not then proceed to copy the database from the application to the users filesystem
        
        // Get the path to the database in the application package
        NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseName];
        
        // Copy the database from the package to the users filesystem
        /*BOOL copy_success =*/ [fileManager copyItemAtPath:databasePathFromApp toPath:databasePath error:nil];	
        
        [fileManager release];
    }

    if (sqlite3_open([databasePath UTF8String], &database) == SQLITE_OK) {
        //Database opened successfully
        JWLog("Opened sqlite db...");
    } else {
        //Failed to open database
        JWLog("Failed to open sqlite db");
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	[FuegoBoard initFuego];
    // Override point for customization after application launch.
	
#ifdef LOGGING
	[self setupLogFile];
#endif

	JWLog("Starting Application...");
#ifdef HOCKEY
    [BWHockeyManager sharedHockeyManager].updateURL = @"http://dgs.uberweiss.net/beta/";
#endif
	
	[self setBlackStone:[UIImage imageNamed:@"Black.png"]];
	[self setWhiteStone:[UIImage imageNamed:@"White.png"]];
	[self setBoardImage:[UIImage imageNamed:@"Board.png"]];
	[self setMessageOff:[UIImage imageNamed:@"Message off.png"]];
	[self setMessageOn:[UIImage imageNamed:@"Message on.png"]];
	JWLog("Loaded Images...");
	
    [self checkAndCreateDatabase];
	
	CurrentGamesController *controller = [[CurrentGamesController alloc] initWithNibName:@"CurrentGamesView" bundle:nil];
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
	
	if ([window respondsToSelector:@selector(setRootViewController:)]) {
		[window setRootViewController:navigationController];
	}
	JWLog("Initialized controllers...");
	
	[navigationController release];
	[controller release];

	[window makeKeyAndVisible];
	JWLog("Showing main window...");
	
	return YES;
}

- (void)invalidateThrottle {
	self.nextRefreshTime = [NSDate date];
}

- (void)resetThrottle {
	self.nextRefreshTime = [NSDate dateWithTimeIntervalSinceNow:THROTTLE_RATE];
}

- (BOOL)refreshThrottled {
	return [[NSDate date] timeIntervalSinceDate:self.nextRefreshTime] < 0;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
	JWLog("Went inactive...");
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
	JWLog("Went into the background...");
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	JWLog("Went into the foreground...");
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
	JWLog("Went active...");
#ifdef LOG_URL
    [self uploadLogFile];
#endif
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	[FuegoBoard finishFuego];
    sqlite3_close(database);
	JWLog("Terminating...");
#ifdef LOGGING
	[self.logFile closeFile];
	self.logFile = nil;
#endif
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
	JWLog("Memory warning...");
}


- (void)dealloc {
	self.nextRefreshTime = nil;
	[blackStone release];
	[whiteStone release];
	[boardImage release];
	[messageOn release];
	[messageOff	release];
    [window release];
    [super dealloc];
}


@end
