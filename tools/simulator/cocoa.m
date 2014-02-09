#import <Cocoa/Cocoa.h>
#include "core.h"

@interface FrameBufferView : NSView
{
    CGDataProviderRef mFbBitsProviderRef;
	int mWidth;
	int mHeight;
	Core *mCore;
}


- (void) setFb: (void*) baseAddress;
- (void) dealloc;
- (void) executeCode;
- (void) setCore: (Core*) core;

@end

@implementation FrameBufferView

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];

	mWidth = frameRect.size.width;
	mHeight = frameRect.size.height;

    return self;
}

- (void) dealloc
{
    if (mFbBitsProviderRef)
        CGDataProviderRelease(mFbBitsProviderRef);

    [super dealloc];
}

- (void) updateFb
{
	if (mFbBitsProviderRef)
        CGDataProviderRelease(mFbBitsProviderRef);

    mFbBitsProviderRef = CGDataProviderCreateWithData(NULL, getCoreFb(mCore), 
		mWidth * 4 * mHeight, NULL);

    [self setNeedsDisplayInRect:NSMakeRect(0, 0, mWidth, mHeight)];
}

- (void) drawRect:(NSRect) rect
{
    CGContextRef viewContextRef = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetInterpolationQuality(viewContextRef, kCGInterpolationNone);
    CGContextSetShouldAntialias(viewContextRef, NO);

    if (mFbBitsProviderRef) 
	{
        CGImageRef imageRef = CGImageCreate(
            mWidth,
            mHeight,
            8, //bitsPerComponent
            32, //bitsPerPixel
            (mWidth * 4), //bytesPerRow
            CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), 
	        kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
            mFbBitsProviderRef, //provider
            NULL, //decode
            0, //interpolate
            kCGRenderingIntentDefault //intent
        );
		
		CGContextDrawImage (viewContextRef, CGRectMake(0, 0, [self bounds].size.width, [self bounds].size.height), imageRef);
		CGImageRelease (imageRef);
    }
}

- (void) executeCode
{
	if (!runQuantum(mCore, 500000))
	{
		printf("app terminated\n");
		[NSApp terminate: nil];
	}
	
	[self updateFb];
}

- (void) setCore: (Core*) core
{
	mCore = core;
}

@end

void runUI(Core *core)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	// Make foreground application with icon in task bar
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);

	[NSApplication sharedApplication];

    NSView *mainView = [[FrameBufferView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 512.0, 512.0)];
	if (!mainView) 
	{
		fprintf(stderr, "Couldn't allocate view\n");
		exit(1);
	}

	[mainView setCore:core];

	NSWindow *mainWindow = [[NSWindow alloc] initWithContentRect:[mainView frame]
		styleMask:NSTitledWindowMask|NSMiniaturizableWindowMask|NSClosableWindowMask
		backing:NSBackingStoreBuffered defer:NO];
	if (!mainWindow) 
	{
		fprintf(stderr, "(cocoa) can't create window\n");
		exit(1);
	}

	[NSApp activateIgnoringOtherApps:YES];
		
	[mainWindow setTitle:[NSString stringWithFormat:@"Framebuffer"]];
	[mainWindow setContentView:mainView];
	[mainWindow useOptimizedDrawing:YES];
	[mainWindow center];
	[mainWindow makeKeyAndOrderFront:nil];

	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0
		target:mainView selector:@selector(executeCode)
		userInfo:nil repeats:YES];

    [NSApp run];

	[pool release];
}
