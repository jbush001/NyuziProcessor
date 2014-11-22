// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 
 

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include "core.h"
#include "device.h"

//
// Code to display live framebuffer contents in a window
//

@interface FrameBufferView : NSView
{
	CGDataProviderRef mFbBitsProviderRef;
	int mWidth;
	int mHeight;
	Core *mCore;
}

- (void) dealloc;
- (void) executeCode;
- (void) setCore: (Core*) core;
- (void) updateFb;
- (void) keyDown:(NSEvent *) event;
- (void) keyUp:(NSEvent *) event;
- (void)flagsChanged:(NSEvent *)event;
- (BOOL) acceptsFirstResponser;

@end

@implementation FrameBufferView

- (id) initWithFrame: (NSRect) frameRect
{
	self = [super initWithFrame: frameRect];

	mWidth = frameRect.size.width;
	mHeight = frameRect.size.height;

	return self;
}

- (void) setFb:(void*) baseAddress
{
	mFbBitsProviderRef = CGDataProviderCreateWithData(NULL, baseAddress, 
		mWidth * 4 * mHeight, NULL);
}

- (void) dealloc
{
	if (mFbBitsProviderRef)
		CGDataProviderRelease(mFbBitsProviderRef);

	[super dealloc];
}

- (void) updateFb
{
	[self setNeedsDisplayInRect:NSMakeRect(0, 0, mWidth, mHeight)];
}

int lastKeyCode = -1;

// PS2 Scan code set 1
const unsigned int kMacKeyToPs2[] = {
	0x1e,	// 0x00 A
	0x1f,	// 0x01 S
	0x20,	// 0x02 D
	0x21,	// 0x03 F
	0x21,	// 0x04 H
	0x22,	// 0x05 G
	0x2c,	// 0x06 Z
	0x2d,	// 0x07 X
	0x2e,	// 0x08 C
	0x2f,	// 0x09 V
	0x00,	// 0x0a unused
	0x30,	// 0x0b B
	0x10,	// 0x0c Q
	0x11,	// 0x0d W
	0x12,	// 0x0e E
	0x13,	// 0x0f R
	0x15,	// 0x10 Y
	0x14,	// 0x11 T
	0x02,	// 0x12 1
	0x03,	// 0x13 2
	0x04,	// 0x14 3
	0x05,	// 0x15 4
	0x07,	// 0x16 6
	0x06,	// 0x17 5
	0x0d,	// 0x18 =
	0x0a,	// 0x19 9
	0x08,	// 0x1a 7
	0x0c, 	// 0x1b -
	0x09, 	// 0x1c 8
	0x0b,	// 0x1d 0
	0x1b,	// 0x1e ]
	0x18,	// 0x1f O
	0x16,	// 0x20 U
	0x1a,	// 0x21 [
	0x17,	// 0x22 I
	0x19,	// 0x23 P
	0x1c,	// 0x24 <return>
	0x26,	// 0x25 L
	0x24, 	// 0x26 J
	0x28,	// 0x27 '
	0x25,	// 0x28 K
	0x27,	// 0x29 ;
	0x2b,	// 0x2a <backslash>
	0x33,	// 0x2b ,
	0x35,	// 0x2c /
	0x31,	// 0x2d N
	0x32,	// 0x2e M
	0x34,	// 0x2f .
	0x0f,	// 0x30 <tab>
	0x39,	// 0x31 <space>
	0x29,	// 0x32 `
	0x00, 	// 0x33 
	0x00, 	// 0x34 
	0x01, 	// 0x35 
};

int lastCode = -1;

- (void) keyDown:(NSEvent *)event
{
	int code = [event keyCode];
	if (code == lastCode)
		return;	// Supress autorepeat, otherwise driver queue fills up
	
	lastCode = code;
	switch (code)
	{
		case kVK_LeftArrow:
			enqueueKey(0xe0);
			enqueueKey(0x4b);
			break;
		case kVK_RightArrow:
			enqueueKey(0xe0);
			enqueueKey(0x4d);
			break;
		case kVK_DownArrow:
			enqueueKey(0xe0);
			enqueueKey(0x50);
			break;
		case kVK_UpArrow:
			enqueueKey(0xe0);
			enqueueKey(0x48);
			break;
		default:	
			enqueueKey(kMacKeyToPs2[code]);
	}
}

- (void) keyUp:(NSEvent *)event
{
	int code = [event keyCode];
	lastCode = -1;
	switch (code)
	{
		case kVK_LeftArrow:
			enqueueKey(0xe0);
			enqueueKey(0xcb);
			break;
		case kVK_RightArrow:
			enqueueKey(0xe0);
			enqueueKey(0xcd);
			break;
		case kVK_DownArrow:
			enqueueKey(0xe0);
			enqueueKey(0xd0);
			break;
		case kVK_UpArrow:
			enqueueKey(0xe0);
			enqueueKey(0xc8);
			break;
		default:	
			enqueueKey(0x80 | kMacKeyToPs2[code]);
	}
}

unsigned int oldModifierFlags = 0;

- (void)flagsChanged:(NSEvent *)event
{
	unsigned changedFlags = oldModifierFlags ^ event.modifierFlags;
	
	if (changedFlags & NSShiftKeyMask)
	{
		if (oldModifierFlags & NSShiftKeyMask)
			enqueueKey(0xaa);	
		else
			enqueueKey(0x2a);	
	}

	if (changedFlags & NSControlKeyMask)
	{
		if (oldModifierFlags & NSControlKeyMask)
			enqueueKey(0x9d);	
		else
			enqueueKey(0x1d);	
	}

	if (changedFlags & NSCommandKeyMask)
	{
		if (oldModifierFlags & NSCommandKeyMask)
			enqueueKey(0xb8);	
		else
			enqueueKey(0x38);	
	}
			
	oldModifierFlags = event.modifierFlags;
}


- (BOOL) acceptsFirstResponser
{
	return YES;
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
			kCGRenderingIntentDefault); //intent
		CGContextDrawImage(viewContextRef, CGRectMake(0, 0, [self bounds].size.width, [self bounds].size.height), imageRef);
		CGImageRelease(imageRef);
	}
}

- (void) executeCode
{
	if (!runQuantum(mCore, -1, 500000))
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

@interface SimAppController : NSObject
{
}
@end

@implementation SimAppController
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}
@end

void runUI(Core *core, int width, int height)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	// Make foreground application with icon in task bar
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);

	[NSApplication sharedApplication];

	NSView *mainView = [[FrameBufferView alloc] initWithFrame:NSMakeRect(0.0, 0.0, width, height)];
	if (!mainView) 
	{
		fprintf(stderr, "Couldn't allocate view\n");
		exit(1);
	}

	[mainView setCore:core];
	[mainView setFb: getCoreFb(core)];

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
	[mainWindow makeKeyAndOrderFront:mainWindow];
	[mainWindow center];
	[mainWindow makeFirstResponder: mainView];
	[NSTimer scheduledTimerWithTimeInterval:0
		target:mainView selector:@selector(executeCode)
		userInfo:nil repeats:YES];

    SimAppController *appController = [[SimAppController alloc] init];
    [NSApp setDelegate:appController];

	[NSApp run];

	[pool release];
}
