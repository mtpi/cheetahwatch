/* 
 * Copyright (c) 2007-2009 Patrick Quinn-Graham, Christoph Nadig
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "CWApplication.h"
#import "CWModel.h"
#import "CWModem.h"
#import "CWDialer.h"
#import "CWBytesValueTransformer.h"
#import "CWCarrierValueTransformer.h"
#import "CWIconValueTransformer.h"
#import "CWModeValueTransformer.h"
#import "CWConnectButtonValueTransformer.h"
#import "CWConnectionStateValueTransformer.h"
#import "CWPrettyPrint.h"
#import "CWSMSContactsController.h"
#import <WebKit/WebKit.h>


@implementation CWApplication

+ (void)initialize
{
    static BOOL beenHere;
    if (!beenHere) {
        //Initialize the value transformers used throughout the application bindings
        [NSValueTransformer setValueTransformer:[CWBytesValueTransformer valueTransformerInSpeedMode:NO] forName:@"CWBytesValueTransformer"];
        [NSValueTransformer setValueTransformer:[CWBytesValueTransformer valueTransformerInSpeedMode:YES] forName:@"CWBytesPerSecondValueTransformer"];
        [NSValueTransformer setValueTransformer:[CWCarrierValueTransformer valueTransformer] forName:@"CWCarrierValueTransformer"];
        [NSValueTransformer setValueTransformer:[CWModeValueTransformer valueTransformer] forName:@"CWModeValueTransformer"];
        [NSValueTransformer setValueTransformer:[CWConnectButtonValueTransformer valueTransformer] forName:@"CWConnectButtonValueTransformer"];
        [NSValueTransformer setValueTransformer:[CWConnectionStateValueTransformer valueTransformer] forName:@"CWConnectionStateValueTransformer"];
        beenHere = YES;
    }
}

- (void)dealloc
{
    [timer invalidate];
    [modem release];
    [dialer release];
    [model release];
    [statusItem release];
    [pinRequestDesc release];
    [smsContactsController release];
    [super dealloc];
}

-(void)showFirstRun
{
    NSString *firstRunVersion =  [[NSUserDefaults standardUserDefaults] objectForKey:@"CWFirstRunVersion"];
    NSString *programVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    // make this version dependent
    if (firstRunVersion == nil || ![firstRunVersion isEqual:programVersion])  {
        WebView *webView = [[[firstRunWindow contentView] subviews] objectAtIndex:0];
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSBundle mainBundle] pathForResource:@"Welcome" ofType:@"html"]]]];
        [firstRunWindow center];
        [firstRunWindow makeKeyAndOrderFront:self];
        [[NSUserDefaults standardUserDefaults] setObject:programVersion forKey:@"CWFirstRunVersion"];
	}
}

// cleanup timer - call model cleanup
- (void)cleanupTimer:(NSTimer *)aTimer
{
    NSCalendarDate *nextRun;
#ifdef DEBUG
    NSLog(@"CWApplication: cleanup timer fired");
#endif
    // cleanup model
    [model cleanupOldConnectionLogs];
    // start new timer for next full hour
    nextRun = [NSCalendarDate date];
    nextRun = [nextRun dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:3600 - (60 * [nextRun minuteOfHour] + [nextRun secondOfMinute])];
    // setup model cleanup timer - this could be done more elegantly, but would be also so much more complicated - good enough for now
    timer = [NSTimer scheduledTimerWithTimeInterval:[nextRun timeIntervalSinceNow] target:self selector:@selector(cleanupTimer:) userInfo:nil repeats:NO];
#ifdef DEBUG
    NSLog(@"CWApplication: next timer scheduled for %@", [timer fireDate]);
#endif
}

- (void)awakeFromNib
{
#ifdef DEBUG
    NSLog(@"CWApplication: awakeFromNib called");
#endif
    // load model
    [self setModel:[CWModel persistentModel]];
    [model setDelegate:self];

    // allocate a modem object handling all input/output - use setter to notify bindings
    [self setModem:[[[CWModem alloc] initWithModel:model] autorelease]];
    [modem setDelegate:self];
    
    // allocate a dialer
    [self setDialer:[[[CWDialer alloc] initWithModel:model] autorelease]];

    // setup menu item
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setEnabled:YES];
	[statusItem setToolTip:NSLocalizedString(@"L120", @"")];
	[statusItem setMenu:statusItemMenu];
    [statusItem setImage:[NSImage imageNamed:@"no-modem-menu"]];

    // manually set up a KVO since the status item does not know anything about bindings (yet)
    [self addObserver:self forKeyPath:@"model.modelForIcon" options:NSKeyValueObservingOptionNew context:NULL];
    
    // KVO for mode preference menu items
    [self addObserver:self forKeyPath:@"model.modesPreference" options:NSKeyValueObservingOptionNew context:NULL];

    // show welcome window on first run
    [self showFirstRun];

    // run cleanup once, then let the timer run it once an hour
    [self cleanupTimer:nil];
    
}

// update status icon - called by binding observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@"model.modelForIcon"]) {
        // still uses a value transformer for this - maybe one day status items know about bindings and we can remove this code
        CWIconValueTransformer *valueTransformer = [CWIconValueTransformer valueTransformer];
        [statusItem setImage:[valueTransformer transformedValue:model]];
    } else if ([keyPath isEqual:@"model.modesPreference"]) {
        CWModesPreference modesPreference = [model modesPreference];
        if ([[modesPrefMenu itemWithTag:modesPreference] state] != NSOnState) {
            // need to refresh menu items enable state
            int ic;
            for(ic = 0; ic < [modesPrefMenu numberOfItems]; ic++) {
                NSMenuItem *menuItem = [modesPrefMenu itemAtIndex:ic];
                if ([menuItem tag] == modesPreference) {
                    [menuItem setState:NSOnState];
                } else {
                    [menuItem setState:NSOffState];
                }
            }
        }
    }
}

// IB Actions
- (IBAction)connectButtonAction:(id)sender
{
    // this is the action of a combined connect/disconnect button - label and taks depends on connected state
    if ([model connected]) {
        // connected/connecting - disconnect now
        [dialer disconnect];
    } else {
        // disconnected - connect now
        [dialer connect];
    }
}

- (IBAction)showAboutPanelAction:(id)sender
{
    // activate application and show standard Cocoa about panel
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:sender];
}

// run APN setter dialog
- (IBAction)setApnMenuAction:(id)sender
{
    [apnField setStringValue:[[model preferences] presetApn]];
    [apnWindow center];
	[NSApp activateIgnoringOtherApps:YES];
    [NSApp beginSheet:apnWindow modalForWindow:nil modalDelegate:self
           didEndSelector:@selector(apnSheetDidEnd:returnCode:context:) contextInfo:nil];
}

- (IBAction)setModesPref:(id)sender
{
    [modem setModesPref:[sender tag]];
}

// APN setter dialog ended
- (void)apnSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode context:(void *)context
{
    if (returnCode == NSOKButton) {
#ifdef DEBUG
    NSLog(@"CWApplication: changing APN to %@", [apnField stringValue]);
#endif
        [[model preferences] setPresetApn:[apnField stringValue]];
        [modem sendApn];
    }
}

// clear connection log
- (IBAction)clearHistoryMenuAction:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"L100", @"") defaultButton:NSLocalizedString(@"L102", @"")
                              alternateButton:NSLocalizedString(@"L103", @"") otherButton:nil
                              informativeTextWithFormat:NSLocalizedString(@"L101", @""), nil];
    // get confirmation for user for clearing history
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector: @selector(clearHistorySheetDidEnd:returnCode:context:) contextInfo:nil];
}

// clear history dialog ended
- (void)clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode context:(void *)context
{
    if (returnCode == NSOKButton) {
#ifdef DEBUG
    NSLog(@"CWApplication: cleaning history");
#endif
        [model clearHistory];
    }
}

// CWModel delegates
- (void)trafficLimitExceeded:(unsigned long long)limit traffic:(unsigned long long)traffic
{
    // only display a dialog unless another one is still open
    if (!trafficWarningDialogOpen) {
        NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"L111", @""), CWPrettyBytes(limit), CWPrettyBytes(traffic)];
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"L110", @"") defaultButton:NSLocalizedString(@"L112", @"")
                                  alternateButton:nil otherButton:nil informativeTextWithFormat:msg];
        [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector: @selector(trafficWarningSheetDidEnd:returnCode:context:) contextInfo:nil];
        trafficWarningDialogOpen = YES;
    }
}

- (void)trafficWarningSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode context:(void *)context
{
    trafficWarningDialogOpen = NO;
}

- (void)setPinRequestDesc:(NSString*)newDesc
{
    [pinRequestDesc release];
    NSMutableString *desc = [[NSMutableString alloc] initWithString:newDesc];
    [desc appendString:@":"];
    pinRequestDesc = desc;
}
- (NSString*)pinRequestDesc
{
    return pinRequestDesc;
}

// CWModem delegates
- (void)needsPin:(NSString*)pinDescription
{
    [self setPinRequestDesc:pinDescription];
    [pinField setStringValue:@""];
    [pinWindow center];
	[NSApp activateIgnoringOtherApps:YES];
    [NSApp beginSheet:pinWindow modalForWindow:nil modalDelegate:self
	   didEndSelector:@selector(pinSheetDidEnd:returnCode:context:) contextInfo:nil];
}

- (void)needsPuk
{
    [pukField setStringValue:@""];
    [newPinField setStringValue:@""];
    [pukWindow center];
	[NSApp activateIgnoringOtherApps:YES];
    [NSApp beginSheet:pukWindow modalForWindow:nil modalDelegate:self
	   didEndSelector:@selector(pukSheetDidEnd:returnCode:context:) contextInfo:nil];
}


// PIN sheet ended
- (void)pinSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode context:(void *)context
{
    if (returnCode == NSOKButton) {
        [modem sendPin:[pinField stringValue]];
    }
}

// PUK sheet ended
- (void)pukSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode context:(void *)context
{
    if (returnCode == NSOKButton) {
        [modem sendPuk:[pukField stringValue] withNewPin:[newPinField stringValue]];
    }
}

- (IBAction)setPinLock:(id)sender
{
    [self setPinRequestDesc:@"SIM PIN"];
    [pinField setStringValue:@""];
    [pinWindow center];
	[NSApp activateIgnoringOtherApps:YES];
    [NSApp beginSheet:pinWindow modalForWindow:nil modalDelegate:self
	   didEndSelector:@selector(pinLockSheetDidEnd:returnCode:context:) contextInfo:sender];
}

- (IBAction)showSMSContactsAction:(id)sender
{
    if (![self smsContactsController]) {
        smsContactsController = [[CWSMSContactsController alloc] initWithWindowNibName:@"SMSContacts"];
        smsContactsController.model = model;
    }
	[smsContactsController showWindow:self];
}

- (void)pinLockSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode context:(void *)context
{
    if (returnCode == NSOKButton) {
        if ([(NSMenuItem*)context tag]==1) {
            [modem setPinLock:YES pin:[pinField stringValue]];
        } else if ([(NSMenuItem*)context tag]==0) {
            [modem setPinLock:NO pin:[pinField stringValue]];
        }
    }
}

// NSApplication delegates
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // synchronize model to disk
    [model synchronize];
}

// accessors
- (CWModel *)model
{
	return model;
}

- (void)setModel:(CWModel *)newModel
{
	[newModel retain];
	[model release];
	model = newModel;
}

- (CWModem *)modem
{
	return modem;
}

- (void)setModem:(CWModem *)newModem
{
	[newModem retain];
	[modem release];
	modem = newModem;
}

- (CWDialer *)dialer
{
	return dialer;
}

- (void)setDialer:(CWDialer *)newDialer
{
	[newDialer retain];
	[dialer release];
	dialer = newDialer;
}

- (CWSMSContactsController *)smsContactsController
{
    return smsContactsController;
}

- (void)setSmsContactsController:(CWSMSContactsController *)newController
{
    [newController retain];
    [smsContactsController release];
    smsContactsController = newController;
}

@end