//
//  MGMSIPWavConverter.m
//  VoiceMac
//
//  Created by Mr. Gecko on 9/15/10.
//  Copyright (c) 2010 Mr. Gecko's Media (James Coleman). All rights reserved. http://mrgeckosmedia.com/
//

#import "MGMSIPWavConverter.h"
#import <VoiceBase/VoiceBase.h>
#import <MGMUsers/MGMUsers.h>
#import <QTKit/QTKit.h>

@implementation MGMSIPWavConverter
- (id)initWithSoundName:(NSString *)theSoundname fileConverting:(NSString *)theFile {
	if (self = [super init]) {
		fileConverting = [theFile copy];
		soundName = [theSoundname copy];
		cancel = NO;
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[notificationCenter addObserver:self selector:@selector(soundChanged:) name:MGMTSoundChangedNotification object:nil];
		movie = [[QTMovie movieWithFile:fileConverting error:NULL] retain];
		if (movie==nil) {
			NSLog(@"Unable to open audio %@", fileConverting);
			[self release];
			self = nil;
		} else if ([[movie attributeForKey:QTMovieLoadStateAttribute] longValue]==2000 || [[movie attributeForKey:QTMovieLoadStateAttribute] longValue]==100000L) {
			[NSThread detachNewThreadSelector:@selector(convertBackground) toTarget:self withObject:nil];
		} else {
			[notificationCenter addObserver:self selector:@selector(movieLoadStateChanged:) name:QTMovieLoadStateDidChangeNotification object:movie];
		}
	}
	return self;
}
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (fileConverting!=nil)
		[fileConverting release];
	if (soundName!=nil)
		[soundName release];
	if (movie!=nil)
		[movie release];
	if (backgroundThread!=nil) {
		while (backgroundThread!=nil) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	}
	[super dealloc];
}

- (void)soundChanged:(NSNotification *)theNotification {
	if ([[theNotification object] isEqual:soundName]) {
		cancel = YES;
		[self release];
	}
}
- (void)movieLoadStateChanged:(NSNotification *)theNotification {
	if ([[movie attributeForKey:QTMovieLoadStateAttribute] longValue]==2000 || [[movie attributeForKey:QTMovieLoadStateAttribute] longValue]==100000L)
		[NSThread detachNewThreadSelector:@selector(convertBackground) toTarget:self withObject:nil];
}
- (void)convertBackground {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	backgroundThread = [[NSThread currentThread] retain];
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
	NSFileManager<NSFileManagerProtocol> *manager = [NSFileManager defaultManager];
	NSString *finalPath = [[MGMUser applicationSupportPath] stringByAppendingPathComponent:MGMTCallSoundsFolder];
	if (![manager fileExistsAtPath:finalPath]) {
		if ([manager respondsToSelector:@selector(createDirectoryAtPath:attributes:)])
			[manager createDirectoryAtPath:finalPath attributes:nil];
		else
			[manager createDirectoryAtPath:finalPath withIntermediateDirectories:YES attributes:nil error:nil];
	}
	finalPath = [finalPath stringByAppendingPathComponent:soundName];
	NSString *convertFinalPath = [[finalPath stringByAppendingPathExtension:@".tmp"] stringByAppendingPathExtension:MGMWavExt];
	finalPath = [finalPath stringByAppendingPathExtension:MGMWavExt];
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], QTMovieExport, [NSNumber numberWithLong:kQTFileTypeWave], QTMovieExportType, [NSNumber numberWithLong:SoundMediaType], QTMovieExportManufacturer, nil];
	if (!cancel) {
        if (![movie writeToFile:convertFinalPath withAttributes:dictionary])
            NSLog(@"Could not convert audio %@", fileConverting);
    }
	if ([manager fileExistsAtPath:finalPath]) {
		if ([manager respondsToSelector:@selector(removeFileAtPath:)])
			[manager removeFileAtPath:finalPath handler:nil];
		else
			[manager removeItemAtPath:finalPath error:nil];
	}
	if (!cancel) {
		if ([manager respondsToSelector:@selector(movePath:toPath:handler:)])
			[manager movePath:convertFinalPath toPath:finalPath handler:nil];
		else
			[manager moveItemAtPath:convertFinalPath toPath:finalPath error:nil];
	}
	[pool drain];
	[backgroundThread release];
	backgroundThread = nil;
	if (!cancel)
		[self release];
}
@end